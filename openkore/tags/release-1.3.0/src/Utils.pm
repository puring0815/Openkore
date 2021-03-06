#########################################################################
#  OpenKore - Utility Functions
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Utility functions
#
# This module contains various general-purpose and independant utility 
# functions. Functions in this module should have <b>no</b> dependancies
# on other Kore modules.

package Utils;

use strict;
no strict 'refs';
use Time::HiRes qw(time usleep);
use IO::Socket::INET;
use Exporter;
use base qw(Exporter);
# Do not use any other Kore modules here. It will create circular dependancies.

our @EXPORT = qw(
	binAdd binFind binFindReverse binRemove binRemoveAndShift binRemoveAndShiftByIndex binSize
	existsInList findIndex findIndexString findIndexString_lc findIndexStringList_lc
	findKey findKeyString minHeapAdd
	distance
	dataWaiting dumpHash formatNumber getCoordString getFormattedDate getHex getTickCount
	getRange inRange
	makeCoords makeCoords2 makeIP swrite timeConvert timeOut vocalString);


#######################################
#######################################
# HASH/ARRAY MANAGEMENT
#######################################
#######################################


##
# binAdd(r_array, ID)
# r_array: a reference to an array.
# ID: the element to add to @r_array.
# Returns: the index of the element inside @r_array.
#
# Add $ID to the first empty slot in @r_array, or append it to
# the end of @r_array if there are no empty slots.
#
# Example:
# @list = ("ID1", undef, "ID2");
# binAdd(\@list, "New");   # --> Returns: 1
# # Result:
# # $list[0] eq "ID1"
# # $list[1] eq "New"
# # $list[2] eq "ID2"
#
# @list = ("ID1", "ID2");
# binAdd(\@list, "New");   # --> Returns: 2
# # Result:
# # $list[0] eq "ID1"
# # $list[1] eq "ID2"
# # $list[2] eq "New"
sub binAdd {
	my $r_array = shift;
	my $ID = shift;
	my $i;
	for ($i = 0; $i <= @{$r_array};$i++) {
		if ($$r_array[$i] eq "") {
			$$r_array[$i] = $ID;
			return $i;
		}
	}
}

##
# binFind(r_array, ID)
# r_array: a reference to an array.
# ID: the element to search for.
# Returns: the index of the element for $ID, or undef is $ID
#          is not an element in @r_array.
#
# Look for element $ID in @r_array.
#
# Example:
# our @array = ("hello", "world", "!");
# binFind(\@array, "world");   # => 1
# binFind(\@array, "?");       # => undef
sub binFind {
	my $r_array = shift;
	my $ID = shift;
	my $i;
	for ($i = 0; $i < @{$r_array};$i++) {
		if ($$r_array[$i] eq $ID) {
			return $i;
		}
	}
	return undef;
}

##
# binFindReverse(r_array, ID)
#
# Same as binFind() but starts looking from the end of the array
# instead of from the beginning.
sub binFindReverse {
	my $r_array = shift;
	my $ID = shift;
	my $i;
	for ($i = @{$r_array} - 1; $i >= 0;$i--) {
		if ($$r_array[$i] eq $ID) {
			return $i;
		}
	}
}

##
# binRemove(r_array, ID)
# r_array: a reference to an array
# ID: the element to remove.
#
# Find a value in @r_array which has the same value as $ID,
# and remove it.
#
# Example:
# our @array = ("hello", "world", "!");
# # Same as: delete $array[1];
# binRemove(\@array, "world");
sub binRemove {
	my $r_array = shift;
	my $ID = shift;
	my $i;
	for ($i = 0; $i < @{$r_array};$i++) {
		if ($$r_array[$i] eq $ID) {
			delete $$r_array[$i];
			last;
		}
	}
}

sub binRemoveAndShift {
	my $r_array = shift;
	my $ID = shift;
	my $found;
	my $i;
	my @newArray;
	for ($i = 0; $i < @{$r_array};$i++) {
		if ($$r_array[$i] ne $ID || $found ne "") {
			push @newArray, $$r_array[$i];
		} else {
			$found = $i;
		}
	}
	@{$r_array} = @newArray;
	return $found;
}

sub binRemoveAndShiftByIndex {
	my $r_array = shift;
	my $index = shift;
	my $found;
	my $i;
	my @newArray;
	for ($i = 0; $i < @{$r_array};$i++) {
		if ($i != $index) {
			push @newArray, $$r_array[$i];
		} else {
			$found = 1;
		}
	}
	@{$r_array} = @newArray;
	return $found;
}

##
# binSize(r_array)
# r_array: a reference to an array.
# Returns: a number.
#
# Calculates the size of @r_array, excluding undefined values.
#
# Example:
# our @array = ("hello", undef, "world");
# scalar @array;        # -> 3
# binSize(\@array);     # -> 2
sub binSize {
	my $r_array = shift;
	my $found = 0;
	my $i;
	for ($i = 0; $i < @{$r_array};$i++) {
		if ($$r_array[$i] ne "") {
			$found++;
		}
	}
	return $found;
}

sub existsInList {
	my ($list, $val) = @_;
	my @array = split / *, */, $list;
	return 0 if ($val eq "");
	$val = lc($val);
	foreach (@array) {
		s/^\s+//;
		s/\s+$//;
		s/\s+/ /g;
		next if ($_ eq "");
		return 1 if (lc($_) eq $val);
	}
	return 0;
}

sub findIndex {
	my $r_array = shift;
	my $match = shift;
	my $ID = shift;
	my $i;

	for ($i = 0; $i < @{$r_array}; $i++) {
		if ((%{$$r_array[$i]} && $$r_array[$i]{$match} == $ID)
			|| (!%{$$r_array[$i]} && $ID eq "")) {
			return $i;
		}
	}
	if ($ID eq "") {
		return $i;
	} else {
		return undef;
	}
}


sub findIndexString {
	my $r_array = shift;
	my $match = shift;
	my $ID = shift;
	my $i;
	for ($i = 0; $i < @{$r_array} ;$i++) {
		if ((%{$$r_array[$i]} && $$r_array[$i]{$match} eq $ID)
			|| (!%{$$r_array[$i]} && $ID eq "")) {
			return $i;
		}
	}
	if ($ID eq "") {
		return $i;
	} else {
		return undef;
	}
}


sub findIndexString_lc {
	my $r_array = shift;
	my $match = shift;
	my $ID = shift;
	my $i;
	for ($i = 0; $i < @{$r_array} ;$i++) {
		if ((%{$$r_array[$i]} && lc($$r_array[$i]{$match}) eq lc($ID))
			|| (!%{$$r_array[$i]} && $ID eq "")) {
			return $i;
		}
	}
	if ($ID eq "") {
		return $i;
	} else {
		return undef;
	}
}

sub findIndexStringList_lc{
	my $r_array = shift;
	my $match = shift;
	my $ID = shift;
	my ($i,$j);
	my @arr = split / *, */, $ID;
	for ($j = 0; $j < @arr; $j++) {
		for ($i = 0; $i < @{$r_array} ;$i++) {
			if (%{$$r_array[$i]} && lc($$r_array[$i]{$match}) eq lc($arr[$j])) {
				return $i;
			}
		}
	}
	if ($ID eq "") {
		return $i;
	} else {
		return undef;
	}
}

sub findKey {
	my $r_hash = shift;
	my $match = shift;
	my $ID = shift;
	foreach (keys %{$r_hash}) {
		if ($r_hash->{$_}{$match} == $ID) {
			return $_;
		}
	}
}

sub findKeyString {
	my $r_hash = shift;
	my $match = shift;
	my $ID = shift;
	foreach (keys %{$r_hash}) {
		if ($$r_hash{$_}{$match} eq $ID) {
			return $_;
		}
	}
}

sub minHeapAdd {
	my $r_array = shift;
	my $r_hash = shift;
	my $match = shift;
	my $i;
	my $found;
	my @newArray;
	for ($i = 0; $i < @{$r_array};$i++) {
		if (!$found && $$r_hash{$match} < $$r_array[$i]{$match}) {
			push @newArray, $r_hash;
			$found = 1;
		}
		push @newArray, $$r_array[$i];
	}
	if (!$found) {
		push @newArray, $r_hash;
	}
	@{$r_array} = @newArray;
}


################################
################################
# MATH
################################

##
# distance(r_hash1, r_hash2)
# r_hash1, r_hash2: references to position hash tables.
# Returns: the distance as integer, in blocks.
#
# Calculates the pythagorean distance between ($r_hash1{x}, $r_hash1{y}) and
# ($r_hash2{x}, $r_hash2{y}).
#
# Example:
# # Calculates the distance between you an a monster
# my $dist = distance($chars[$config{char}]{pos_to},
#                     $monsters{$ID}{pos_to});
sub distance {
	my $r_hash1 = shift;
	my $r_hash2 = shift;
	my %line;
	if ($r_hash2) {
		$line{'x'} = abs($$r_hash1{'x'} - $$r_hash2{'x'});
		$line{'y'} = abs($$r_hash1{'y'} - $$r_hash2{'y'});
	} else {
		%line = %{$r_hash1};
	}
	return sqrt($line{'x'} ** 2 + $line{'y'} ** 2);
}


################################
################################
################################
# MISC UTILITY FUNCTIONS
################################
################################


##
# dataWaiting(r_handle)
# r_handle: A reference to a handle or a socket.
# Returns: 1 if there's pending incoming data, 0 if not.
#
# Checks whether r_handle has pending incoming data.
# If there is, then you can read from r_handle without being blocked.
sub dataWaiting {
	my $r_fh = shift;
	my $bits = '';

	vec($bits, fileno($$r_fh), 1) = 1;
	# The timeout was 0.005
	return (select($bits, undef, undef, 0) > 0);
	#return select($bits, $bits, $bits, 0) > 1);
}

##
# dumpHash(r_hash)
# r_hash: a reference to a hash.
#
# Return a formated output of the contents of hash, for debugging purposes.
sub dumpHash {
	my $out;
	my $buf = $_[0];
	if (ref($buf) eq "") {
		$buf =~ s/'/\\'/gs;
		$buf =~ s/\W/\./gs;
		$out .= "'$buf'";
	} elsif (ref($buf) eq "HASH") {
		$out .= "{";
		foreach (keys %{$buf}) {
			s/'/\\'/gs;
			$out .= "$_=>" . dumpHash($buf->{$_}) . ",";
		}
		chop $out;
		$out .= "}";
	}
	$out = '{empty}' if ($out eq '}');
	return $out;
}

##
# formatNumber(num)
# num: An integer number.
# Returns: A formatted number with commas.
#
# Add commas to $num so large numbers are more readable.
# $num must be an integer, not a floating point number.
#
# Example:
# formatNumber(1000000);   # -> 1,000,000

#umm i tweeked it a little, just to make it display as described ;) -xlr82xs
sub formatNumber {
	my $num = reverse $_[0];
	if ($num == 0) {
		return 0;
	}else {
		$num =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
		return scalar reverse $num;
	}
}

sub getCoordString {
	my $x = int scalar shift;
	my $y = int scalar shift;
	return pack("C*", int($x / 4), ($x % 4) * 64 + int($y / 16), ($y % 16) * 16);
}

sub getFormattedDate {
        my $thetime = shift;
        my $r_date = shift;
        my @localtime = localtime $thetime;
        my $themonth = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)[$localtime[4]];
        $localtime[2] = "0" . $localtime[2] if ($localtime[2] < 10);
        $localtime[1] = "0" . $localtime[1] if ($localtime[1] < 10);
        $localtime[0] = "0" . $localtime[0] if ($localtime[0] < 10);
        $$r_date = "$themonth $localtime[3] $localtime[2]:$localtime[1]:$localtime[0] " . ($localtime[5] + 1900);
        return $$r_date;
}

sub getHex {
	my $data = shift;
	my $i;
	my $return;
	for ($i = 0; $i < length($data); $i++) {
		$return .= uc(unpack("H2",substr($data, $i, 1)));
		if ($i + 1 < length($data)) {
			$return .= " ";
		}
	}
	return $return;
}

sub getTickCount {
	my $time = int(time()*1000);
	if (length($time) > 9) {
		return substr($time, length($time) - 8, length($time));
	} else {
		return $time;
	}
}

sub makeCoords {
	my $r_hash = shift;
	my $rawCoords = shift;
	$$r_hash{'x'} = unpack("C", substr($rawCoords, 0, 1)) * 4 + (unpack("C", substr($rawCoords, 1, 1)) & 0xC0) / 64;
	$$r_hash{'y'} = (unpack("C",substr($rawCoords, 1, 1)) & 0x3F) * 16 + 
				(unpack("C",substr($rawCoords, 2, 1)) & 0xF0) / 16;
}

sub makeCoords2 {
	my $r_hash = shift;
	my $rawCoords = shift;
	$$r_hash{'x'} = (unpack("C",substr($rawCoords, 1, 1)) & 0xFC) / 4 + 
				(unpack("C",substr($rawCoords, 0, 1)) & 0x0F) * 64;
	$$r_hash{'y'} = (unpack("C", substr($rawCoords, 1, 1)) & 0x03) * 256 + unpack("C", substr($rawCoords, 2, 1));
}

sub makeIP {
	my $raw = shift;
	my $ret;
	for (my $i = 0; $i < 4; $i++) {
		$ret .= hex(getHex(substr($raw, $i, 1)));
		if ($i + 1 < 4) {
			$ret .= ".";
		}
	}
	return $ret;
}

sub swrite {
	my $result = '';
	for (my $i = 0; $i < @_; $i += 2) {
		my $format = $_[$i];
		my @args = @{$_[$i+1]};
		if ($format =~ /@[<|>]/) {
			$^A = '';
			formline($format, @args);
			$result .= "$^A\n";
		} else {
			$result .= "$format\n";
		}
	}
	$^A = '';
	return $result;
}

##
# timeConvert(seconds)
# seconds: number of seconds.
# Returns: a human-readable version of $seconds.
#
# Converts $seconds into a string in the form of "x hours y minutes z seconds".
sub timeConvert {
	my $time = shift;
	my $hours = int($time / 3600);
	my $time = $time % 3600;
	my $minutes = int($time / 60);
	my $time = $time % 60;
	my $seconds = $time;
	my $gathered = '';

	$gathered = "$hours hours " if ($hours);
	$gathered .= "$minutes minutes " if ($minutes);
	$gathered .= "$seconds seconds" if ($seconds);
	$gathered =~ s/ $//;
	$gathered = '0 seconds' if ($gathered eq '');
	return $gathered;
}

##
# timeOut(r_time, [timeout])
# r_time: a time value, or a hash.
# timeout: the timeout value to use if $r_time is a time value.
# Returns: a boolean.
#
# If r_time is a time value:
# Check whether $timeout seconds have passed since $r_time.
#
# If r_time is a hash:
# Check whether $r_time->{timeout} seconds have passed since $r_time->{time}.
#
# This function is usually used to handle timeouts in a loop.
#
# Example:
# my %time;
# $time{time} = time;
# $time{timeout} = 10;
#
# while (1) {
#     if (timeOut(\%time)) {
#         print "10 seconds have passed since this loop was started.\n";
#         last;
#     }
# }
#
# my $startTime = time;
# while (1) {
#     if (timeOut($startTime, 6)) {
#         print "6 seconds have passed since this loop was started.\n";
#         last;
#     }
# }
sub timeOut {
	my ($r_time, $compare_time) = @_;
	if ($compare_time ne "") {
		return (time - $r_time > $compare_time);
	} else {
		return (time - $$r_time{'time'} > $$r_time{'timeout'});
	}
}

##
# vocalString(letter_length, [r_string])
# letter_length: the requested length of the result.
# r_string: a reference to a scalar. If given, the result will be stored here.
# Returns: the resulting string.
#
# Creates a random string of $letter_length long. The resulting string is pronouncable.
# This function can be used to generate a random password.
#
# Example:
# for (my $i = 0; $i < 5; $i++) {
#     printf("%s\n", vocalString(10));
# }
sub vocalString {
	my $letter_length = shift;
	return if ($letter_length <= 0);
	my $r_string = shift;
	my $test;
	my $i;
	my $password;
	my @cons = ("b", "c", "d", "g", "h", "j", "k", "l", "m", "n", "p", "r", "s", "t", "v", "w", "y", "z", "tr", "cl", "cr", "br", "fr", "th", "dr", "ch", "st", "sp", "sw", "pr", "sh", "gr", "tw", "wr", "ck");
	my @vowels = ("a", "e", "i", "o", "u" , "a", "e" ,"i","o","u","a","e","i","o", "ea" , "ou" , "ie" , "ai" , "ee" ,"au", "oo");
	my %badend = ( "tr" => 1, "cr" => 1, "br" => 1, "fr" => 1, "dr" => 1, "sp" => 1, "sw" => 1, "pr" =>1, "gr" => 1, "tw" => 1, "wr" => 1, "cl" => 1);
	for (;;) {
		$password = "";
		for($i = 0; $i < $letter_length; $i++){
			$password .= $cons[rand(@cons - 1)] . $vowels[rand(@vowels - 1)];
		}
		$password = substr($password, 0, $letter_length);
		($test) = ($password =~ /(..)\z/);
		last if ($badend{$test} != 1);
	}
	$$r_string = $password if ($r_string);
	return $password;
}

sub inRange {
	my $value = shift;
	my $param = shift;

	return 1 if (!defined $param);
	my ($min, $max) = getRange($param);

	if (defined $min && defined $max) {
		return 1 if ($value >= $min && $value <= $max);
	} elsif (defined $min) {
		return 1 if ($value >= $min);
	} elsif (defined $max) {
		return 1 if ($value <= $max);
	}
	
	return 0;
}

sub getRange {
	my $param = shift;
	return if (!defined $param);

	if (($param =~ /(\d+)\s*-\s*(\d+)/) || ($param =~ /(\d+)\s*\.\.\s*(\d+)/)) {
		return ($1, $2);
	} elsif ($param =~ />\s*(\d+)/) {
		return ($1+1, undef);
	} elsif ($param =~ />=\s*(\d+)/) {
		return ($1, undef);
	} elsif ($param =~ /<\s*(\d+)/) {
		return (undef, $1-1);
	} elsif ($param =~ /<=\s*(\d+)/) {
		return (undef, $1);
	} elsif ($param =~/^(\d+)/) {
		return ($1, $1);
	}
}

return 1;
