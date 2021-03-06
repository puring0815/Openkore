<?php
# Copyright (C) 2006 Greg Sabino Mullane <greg@turnstep.com>
# http://www.mediawiki.org/
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
# http://www.gnu.org/copyleft/gpl.html

## XXX Better catching of SELECT to_tsquery('the')

/**
 * Search engine hook base class for Postgres
 * @package MediaWiki
 * @subpackage Search
 */

/** @package MediaWiki */
class SearchPostgres extends SearchEngine {

	function SearchPostgres( &$db ) {
		$this->db =& $db;
	}

	/**
	 * Perform a full text search query via tsearch2 and return a result set.
	 * Currently searches a page's current title (p.page_title) and text (t.old_text)
	 *
	 * @param string $term - Raw search term
	 * @return PostgresSearchResultSet
	 * @access public
	 */
	function searchText( $term ) {
		$resultSet = $this->db->resultObject( $this->db->query( $this->searchQuery( $term, 'textvector' ) ) );
		return new PostgresSearchResultSet( $resultSet, $this->searchTerms );
	}
	function searchTitle( $term ) {
		$resultSet = $this->db->resultObject( $this->db->query( $this->searchQuery( $term , 'titlevector' ) ) );
		return new PostgresSearchResultSet( $resultSet, $this->searchTerms );
	}


	/*
	 * Transform the user's search string into a better form for tsearch2
	*/
	function parseQuery( $filteredText, $fulltext ) {
		global $wgContLang;
		$lc = SearchEngine::legalSearchChars();
		$searchon = '';
		$this->searchTerms = array();

		# FIXME: This doesn't handle parenthetical expressions.
		if( preg_match_all( '/([-+<>~]?)(([' . $lc . ']+)(\*?)|"[^"]*")/',
			  $filteredText, $m, PREG_SET_ORDER ) ) {
			foreach( $m as $terms ) {
				if( $searchon !== '' ) $searchon .= ' ';
				if($terms[1] == '') {
					$terms[1] = '+';
				}
				$searchon .= $terms[1] . $wgContLang->stripForSearch( $terms[2] );
				if( !empty( $terms[3] ) ) {
					$regexp = preg_quote( $terms[3], '/' );
					if( $terms[4] ) $regexp .= "[0-9A-Za-z_]+";
				} else {
					$regexp = preg_quote( str_replace( '"', '', $terms[2] ), '/' );
				}
				$this->searchTerms[] = $regexp;
			}
			wfDebug( "Would search with '$searchon'\n" );
			wfDebug( "Match with /\b" . implode( '\b|\b', $this->searchTerms ) . "\b/\n" );
		} else {
			wfDebug( "Can't understand search query '{$this->filteredText}'\n" );
		}

		$searchon = preg_replace('/(\s+)/','&',$searchon);
		$searchon = $this->db->strencode( $searchon );
		return $searchon;
	}

	/**
	 * Construct the full SQL query to do the search.
	 * @param string $filteredTerm
	 * @param string $fulltext
	 * @private
	 */
	function searchQuery( $filteredTerm, $fulltext ) {

		$match = $this->parseQuery( $filteredTerm, $fulltext );

		$query = "SELECT page_id, page_namespace, page_title, old_text AS page_text ".
			"FROM page p, revision r, pagecontent c WHERE p.page_latest = r.rev_id " .
			"AND r.rev_text_id = c.old_id AND $fulltext @@ to_tsquery('default','$match')";

		## Redirects
		if (! $this->showRedirects)
			$query .= ' AND page_is_redirect = 0'; ## IS FALSE

		## Namespaces - defaults to 0
		if ( count($this->namespaces) < 1)
			$query .= ' AND page_namespace = 0';
		else {
			$namespaces = implode( ',', $this->namespaces );
			$query .=  " AND page_namespace IN ($namespaces)";
		}

		$query .= " ORDER BY rank($fulltext, to_tsquery('default','$fulltext')) DESC";

		$query .= $this->db->limitResult( '', $this->limit, $this->offset );

		return $query;
	}

	## These two functions are done automatically via triggers

	function update( $id, $title, $text ) { return true; }
    function updateTitle( $id, $title )   { return true; }

} ## end of the SearchPostgres class


/** @package MediaWiki */
class PostgresSearchResultSet extends SearchResultSet {
	function PostgresSearchResultSet( $resultSet, $terms ) {
		$this->mResultSet = $resultSet;
		$this->mTerms = $terms;
	}

	function termMatches() {
		return $this->mTerms;
	}

	function numRows() {
		return $this->mResultSet->numRows();
	}

	function next() {
		$row = $this->mResultSet->fetchObject();
		if( $row === false ) {
			return false;
		} else {
			return new SearchResult( $row );
		}
	}
}

?>
