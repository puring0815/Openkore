<?php


/*
 * Created on Sep 7, 2006
 *
 * API for MediaWiki 1.8+
 *
 * Copyright (C) 2006 Yuri Astrakhan <FirstnameLastname@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 * http://www.gnu.org/copyleft/gpl.html
 */

if (!defined('MEDIAWIKI')) {
	// Eclipse helper - will be ignored in production
	require_once ('ApiQueryBase.php');
}

class ApiQueryRevisions extends ApiQueryBase {

	public function __construct($query, $moduleName) {
		parent :: __construct($query, $moduleName, 'rv');
	}

	public function execute() {
		$limit = $startid = $endid = $start = $end = $dir = $prop = null;
		extract($this->extractRequestParams());

		$db = $this->getDB();

		// true when ordered by timestamp from older to newer, false otherwise
		$dirNewer = ($dir === 'newer');

		// If any of those parameters are used, work in 'enumeration' mode.
		// Enum mode can only be used when exactly one page is provided.
		// Enumerating revisions on multiple pages make it extremelly 
		// difficult to manage continuations and require additional sql indexes  
		$enumRevMode = ($limit !== 0 || $startid !== 0 || $endid !== 0 || $dirNewer || isset ($start) || isset ($end));

		$pageSet = $this->getPageSet();
		$pageCount = $pageSet->getGoodTitleCount();
		$revCount = $pageSet->getRevisionCount();

		// Optimization -- nothing to do
		if ($revCount === 0 && $pageCount === 0)
			return;

		if ($revCount > 0 && $pageCount > 0)
			$this->dieUsage('The revids= parameter may not be used with titles, pageids, or generator options.', 'revids');

		if ($revCount > 0 && $enumRevMode)
			$this->dieUsage('The revids= parameter may not be used with the list options (limit, startid, endid, dirNewer, start, end).', 'revids');

		if ($revCount === 0 && $pageCount > 1 && $enumRevMode)
			$this->dieUsage('titles, pageids or a generator was used to supply multiple pages, but the limit, startid, endid, dirNewer, start, and end parameters may only be used on a single page.', 'multpages');

		$tables = array (
			'revision'
		);
		$fields = array (
			'rev_id',
			'rev_page',
			'rev_text_id',
			'rev_minor_edit'
		);
		$conds = array (
			'rev_deleted' => 0
		);
		$options = array ();

		$showTimestamp = $showUser = $showComment = $showContent = false;
		if (isset ($prop)) {
			foreach ($prop as $p) {
				switch ($p) {
					case 'timestamp' :
						$fields[] = 'rev_timestamp';
						$showTimestamp = true;
						break;
					case 'user' :
						$fields[] = 'rev_user';
						$fields[] = 'rev_user_text';
						$showUser = true;
						break;
					case 'comment' :
						$fields[] = 'rev_comment';
						$showComment = true;
						break;
					case 'content' :
						$tables[] = 'text';
						$conds[] = 'rev_text_id=old_id';
						$fields[] = 'old_id';
						$fields[] = 'old_text';
						$fields[] = 'old_flags';
						$showContent = true;
						break;
					default :
						ApiBase :: dieDebug(__METHOD__, "unknown prop $p");
				}
			}
		}

		$userMax = ($showContent ? 50 : 500);
		$botMax = ($showContent ? 200 : 10000);

		if ($enumRevMode) {

			// This is mostly to prevent parameter errors (and optimize sql?)
			if ($startid !== 0 && isset ($start))
				$this->dieUsage('start and startid cannot be used together', 'badparams');

			if ($endid !== 0 && isset ($end))
				$this->dieUsage('end and endid cannot be used together', 'badparams');

			// This code makes an assumption that sorting by rev_id and rev_timestamp produces
			// the same result. This way users may request revisions starting at a given time,
			// but to page through results use the rev_id returned after each page.
			// Switching to rev_id removes the potential problem of having more than 
			// one row with the same timestamp for the same page. 
			// The order needs to be the same as start parameter to avoid SQL filesort.
			$options['ORDER BY'] = ($startid !== 0 ? 'rev_id' : 'rev_timestamp') . ($dirNewer ? '' : ' DESC');

			$before = ($dirNewer ? '<=' : '>=');
			$after = ($dirNewer ? '>=' : '<=');

			if ($startid !== 0)
				$conds[] = 'rev_id' . $after . intval($startid);
			if ($endid !== 0)
				$conds[] = 'rev_id' . $before . intval($endid);
			if (isset ($start))
				$conds[] = 'rev_timestamp' . $after . $db->addQuotes($start);
			if (isset ($end))
				$conds[] = 'rev_timestamp' . $before . $db->addQuotes($end);

			// must manually initialize unset limit
			if (!isset ($limit))
				$limit = 10;

			$this->validateLimit($this->encodeParamName('limit'), $limit, 1, $userMax, $botMax);

			// There is only one ID, use it
			$conds['rev_page'] = array_pop(array_keys($pageSet->getGoodTitles()));

		}
		elseif ($pageCount > 0) {
			// When working in multi-page non-enumeration mode,
			// limit to the latest revision only
			$tables[] = 'page';
			$conds[] = 'page_id=rev_page';
			$conds[] = 'page_latest=rev_id';
			$this->validateLimit('page_count', $pageCount, 1, $userMax, $botMax);

			// Get all page IDs
			$conds['page_id'] = array_keys($pageSet->getGoodTitles());

			$limit = $pageCount; // assumption testing -- we should never get more then $pageCount rows.
		}
		elseif ($revCount > 0) {
			$this->validateLimit('rev_count', $revCount, 1, $userMax, $botMax);

			// Get all revision IDs
			$conds['rev_id'] = array_keys($pageSet->getRevisionIDs());

			$limit = $revCount; // assumption testing -- we should never get more then $revCount rows.
		} else
			ApiBase :: dieDebug(__METHOD__, 'param validation?');

		$options['LIMIT'] = $limit +1;

		$this->profileDBIn();
		$res = $db->select($tables, $fields, $conds, __METHOD__, $options);
		$this->profileDBOut();

		$data = array ();
		$count = 0;
		while ($row = $db->fetchObject($res)) {

			if (++ $count > $limit) {
				// We've reached the one extra which shows that there are additional pages to be had. Stop here...
				if (!$enumRevMode)
					ApiBase :: dieDebug(__METHOD__, 'Got more rows then expected'); // bug report

				$startStr = 'startid=' . $row->rev_id;
				$msg = array (
					'continue' => $startStr
				);
				$this->getResult()->addValue('query-status', 'revisions', $msg);
				break;
			}

			$vals = array (
				'revid' => intval($row->rev_id
			), 'oldid' => intval($row->rev_text_id));

			if ($row->rev_minor_edit) {
				$vals['minor'] = '';
			}

			if ($showTimestamp)
				$vals['timestamp'] = wfTimestamp(TS_ISO_8601, $row->rev_timestamp);

			if ($showUser) {
				$vals['user'] = $row->rev_user_text;
				if (!$row->rev_user)
					$vals['anon'] = '';
			}

			if ($showComment)
				$vals['comment'] = $row->rev_comment;

			if ($showContent) {
				ApiResult :: setContent($vals, Revision :: getRevisionText($row));
			}

			$this->getResult()->addValue(array (
				'query',
				'pages',
				intval($row->rev_page
			), 'revisions'), intval($row->rev_id), $vals);
		}
		$db->freeResult($res);

		// Ensure that all revisions are shown as '<r>' elements
		$data = & $this->getResultData();
		foreach ($data['query']['pages'] as & $page) {
			if (is_array($page) && array_key_exists('revisions', $page)) {
				ApiResult :: setIndexedTagName($page['revisions'], 'rev');
			}
		}
	}

	protected function getAllowedParams() {
		return array (
			'prop' => array (
				ApiBase :: PARAM_ISMULTI => true,
				ApiBase :: PARAM_TYPE => array (
					'timestamp',
					'user',
					'comment',
					'content'
				)
			),
			'limit' => array (
				ApiBase :: PARAM_DFLT => 0,
				ApiBase :: PARAM_TYPE => 'limit',
				ApiBase :: PARAM_MIN => 0,
				ApiBase :: PARAM_MAX1 => 50,
				ApiBase :: PARAM_MAX2 => 500
			),
			'startid' => 0,
			'endid' => 0,
			'start' => array (
				ApiBase :: PARAM_TYPE => 'timestamp'
			),
			'end' => array (
				ApiBase :: PARAM_TYPE => 'timestamp'
			),
			'dir' => array (
				ApiBase :: PARAM_DFLT => 'older',
				ApiBase :: PARAM_TYPE => array (
					'newer',
					'older'
				)
			)
		);
	}

	protected function getParamDescription() {
		return array (
			'prop' => 'Which properties to get for each revision: user|timestamp|comment|content',
			'limit' => 'limit how many revisions will be returned (enum)',
			'startid' => 'from which revision id to start enumeration (enum)',
			'endid' => 'stop revision enumeration on this revid (enum)',
			'start' => 'from which revision timestamp to start enumeration (enum)',
			'end' => 'enumerate up to this timestamp (enum)',
			'dir' => 'direction of enumeration - towards "newer" or "older" revisions (enum)'
		);
	}

	protected function getDescription() {
		return array (
			'Get revision information.',
			'This module may be used in several ways:',
			' 1) Get data about a set of pages (last revision), by setting titles or pageids parameter.',
			' 2) Get revisions for one given page, by using titles/pageids with start/end/limit params.',
			' 3) Get data about a set of revisions by setting their IDs with revids parameter.',
			'All parameters marked as (enum) may only be used with a single page (#2).'
		);
	}

	protected function getExamples() {
		return array (
			'Get data with content for the last revision of titles "API" and "Main Page":',
			'  api.php?action=query&prop=revisions&titles=API|Main%20Page&rvprop=timestamp|user|comment|content',
			'Get last 5 revisions of the "Main Page":',
			'  api.php?action=query&prop=revisions&titles=Main%20Page&rvlimit=5&rvprop=timestamp|user|comment',
			'Get first 5 revisions of the "Main Page":',
			'  api.php?action=query&prop=revisions&titles=Main%20Page&rvlimit=5&rvprop=timestamp|user|comment&rvdir=newer',
			'Get first 5 revisions of the "Main Page" made after 2006-05-01:',
			'  api.php?action=query&prop=revisions&titles=Main%20Page&rvlimit=5&rvprop=timestamp|user|comment&rvdir=newer&rvstart=20060501000000'
		);
	}

	public function getVersion() {
		return __CLASS__ . ': $Id: ApiQueryRevisions.php 16757 2006-10-03 05:41:55Z yurik $';
	}
}
?>