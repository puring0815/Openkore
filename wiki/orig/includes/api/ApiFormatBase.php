<?php


/*
 * Created on Sep 19, 2006
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
	require_once ('ApiBase.php');
}

abstract class ApiFormatBase extends ApiBase {

	private $mIsHtml, $mFormat;

	/**
	* Constructor
	*/
	public function __construct($main, $format) {
		parent :: __construct($main, $format);

		$this->mIsHtml = (substr($format, -2, 2) === 'fm'); // ends with 'fm'
		if ($this->mIsHtml)
			$this->mFormat = substr($format, 0, -2); // remove ending 'fm'
		else
			$this->mFormat = $format;
		$this->mFormat = strtoupper($this->mFormat);
	}

	/**
	 * Overriding class returns the mime type that should be sent to the client.
	 * This method is not called if getIsHtml() returns true.
	 * @return string
	 */
	public abstract function getMimeType();

	public function getNeedsRawData() {
		return false;
	}

	/**
	 * Returns true when an HTML filtering printer should be used.
	 * The default implementation assumes that formats ending with 'fm' 
	 * should be formatted in HTML. 
	 */
	public function getIsHtml() {
		return $this->mIsHtml;
	}

	/**
	 * Initialize the printer function and prepares the output headers, etc.
	 * This method must be the first outputing method during execution.
	 * A help screen's header is printed for the HTML-based output
	 */
	function initPrinter($isError) {
		$isHtml = $this->getIsHtml();
		$mime = $isHtml ? 'text/html' : $this->getMimeType();
		header("Content-Type: $mime; charset=utf-8;");

		if ($isHtml) {
?>
		<html>
		<head>
			<title>MediaWiki API</title>
		</head>
		<body>
<?php


			if (!$isError) {
?>
			<br/>
			<small>
			This result is being shown in <?=$this->mFormat?> format,
			which might not be suitable for your application.<br/>
			See <a href='api.php'>API help</a> for more information.<br/>
			</small>
<?php


			}
?>
		<pre>
<?php


		}
	}

	/**
	 * Finish printing. Closes HTML tags.
	 */
	public function closePrinter() {
		if ($this->getIsHtml()) {
?>
		</pre>
		</body>
<?php


		}
	}

	public function printText($text) {
		if ($this->getIsHtml())
			echo $this->formatHTML($text);
		else
			echo $text;
	}

	/**
	* Prety-print various elements in HTML format, such as xml tags and URLs.
	* This method also replaces any '<' with &lt;
	*/
	protected function formatHTML($text) {
		// encode all tags as safe blue strings
		$text = ereg_replace('\<([^>]+)\>', '<font color=blue>&lt;\1&gt;</font>', $text);
		// identify URLs
		$text = ereg_replace("[a-zA-Z]+://[^ '()<\n]+", '<a href="\\0">\\0</a>', $text);
		// identify requests to api.php
		$text = ereg_replace("api\\.php\\?[^ ()<\n\t]+", '<a href="\\0">\\0</a>', $text);
		// make strings inside * bold
		$text = ereg_replace("\\*[^<>\n]+\\*", '<b>\\0</b>', $text);
		// make strings inside $ italic
		$text = ereg_replace("\\$[^<>\n]+\\$", '<b><i>\\0</i></b>', $text);

		return $text;
	}

	/**
	 * Returns usage examples for this format.
	 */
	protected function getExamples() {
		return 'api.php?action=query&meta=siteinfo&si=namespaces&format=' . $this->getModuleName();
	}

	public static function getBaseVersion() {
		return __CLASS__ . ': $Id: ApiFormatBase.php 16757 2006-10-03 05:41:55Z yurik $';
	}
}
?>