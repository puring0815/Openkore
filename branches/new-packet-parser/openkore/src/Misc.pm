#########################################################################
#  OpenKore - Miscellaneous functions
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
##
# MODULE DESCRIPTION: Miscellaneous functions
#
# This module contains functions that do not belong in any other modules.
# The difference between Misc.pm and Utils.pm is that Misc.pm can have
# dependencies on other Kore modules.

package Misc;

use strict;
use Exporter;
use base qw(Exporter);

use Globals;
use Log qw(message warning error debug);
use Plugins;
use FileParsers;
use Settings;
use Utils;
use Network::Send;

our @EXPORT = (
	# Config modifiers
	qw/auth
	configModify
	setTimeout
	saveConfigFile/,

	# Debugging
	qw/debug_showSpots
	visualDump/,

	# Field math
	qw/calcRectArea
	calcRectArea2
	checkFieldSnipable
	checkFieldWalkable
	checkFieldWater
	checkLineSnipable
	checkLineWalkable
	checkWallLength
	closestWalkableSpot
	getFieldPoint
	objectInsideSpell
	objectIsMovingTowards
	objectIsMovingTowardsPlayer/,

	# Inventory management
	qw/inInventory
	inventoryItemRemoved
	storageGet
	cardName
	itemName
	itemNameSimple/,

	#File Parsing and Writing
	qw/chatLog
	shopLog
	monsterLog
	convertGatField
	getField
	getGatField/,

	# Logging
	qw/itemLog/,

	# OS specific
	qw/launchURL/,

	# Misc
	qw/
	avoidGM_talk
	avoidList_talk
	calcStat
	center
	charSelectScreen
	chatLog_clear
	checkAllowedMap
	checkFollowMode
	checkMonsterCleanness
	createCharacter
	deal
	dealAddItem
	drop
	dumpData
	getIDFromChat
	getPortalDestName
	getResponse
	getSpellName
	headgearName
	itemLog_clear
	look
	lookAtPosition
	manualMove
	objectAdded
	objectRemoved
	items_control
	mon_control
	positionNearPlayer
	positionNearPortal
	printItemDesc
	quit
	relog
	sendMessage
	setSkillUseTimer
	setPartySkillTimer
	setStatus
	countCastOn
	stopAttack
	stripLanguageCode
	switchConfigFile
	updateDamageTables
	useTeleport
	whenGroundStatus
	whenStatusActive
	whenStatusActiveMon
	whenStatusActivePL
	writeStorageLog/
	);


# use SelfLoader; 1;
# __DATA__



#######################################
#######################################
### CATEGORY: Configuration modifiers
#######################################
#######################################

sub auth {
	my $user = shift;
	my $flag = shift;
	if ($flag) {
		message "Authorized user '$user' for admin\n", "success";
	} else {
		message "Revoked admin privilages for user '$user'\n", "success";
	}
	$overallAuth{$user} = $flag;
	writeDataFile("$Settings::control_folder/overallAuth.txt", \%overallAuth);
}

##
# configModify(key, val, [silent])
# key: a key name.
# val: the new value.
# silent: if set to 1, do not print a message to the console.
#
# Changes the value of the configuration variable $key to $val.
# %config and config.txt will be updated.
sub configModify {
	my $key = shift;
	my $val = shift;
	my $silent = shift;

	Plugins::callHook('configModify', {
		key => $key,
		val => $val,
		silent => $silent
	});

	message("Config '$key' set to $val (was $config{$key})\n", "info") unless ($silent);
	$config{$key} = $val;
	saveConfigFile();
}

##
# saveConfigFile()
#
# Writes %config to config.txt.
sub saveConfigFile {
	writeDataFileIntact($Settings::config_file, \%config);
}

sub setTimeout {
	my $timeout = shift;
	my $time = shift;
	message "Timeout '$timeout' set to $time (was $timeout{$timeout}{timeout})\n", "info";
	$timeout{$timeout}{'timeout'} = $time;
	writeDataFileIntact2("$Settings::control_folder/timeouts.txt", \%timeout);
}


#######################################
#######################################
### Category: Debugging
#######################################
#######################################

our %debug_showSpots_list;

sub debug_showSpots {
	return unless $xkore;
	my $ID = shift;
	my $spots = shift;
	my $special = shift;

	if ($debug_showSpots_list{$ID}) {
		foreach (@{$debug_showSpots_list{$ID}}) {
			my $msg = pack("C*", 0x20, 0x01) . pack("L", $_);
			sendToClientByInject(\$remote_socket, $msg);
		}
	}

	my $i = 1554;
	$debug_showSpots_list{$ID} = [];
	foreach (@{$spots}) {
		next if !defined $_;
		my $msg = pack("C*", 0x1F, 0x01)
			. pack("L*", $i, 1550)
			. pack("S*", $_->{x}, $_->{y})
			. pack("C*", 0x93, 0);
		sendToClientByInject(\$remote_socket, $msg);
		sendToClientByInject(\$remote_socket, $msg);
		push @{$debug_showSpots_list{$ID}}, $i;
		$i++;
	}

	if ($special) {
		my $msg = pack("C*", 0x1F, 0x01)
			. pack("L*", 1553, 1550)
			. pack("S*", $special->{x}, $special->{y})
			. pack("C*", 0x83, 0);
		sendToClientByInject(\$remote_socket, $msg);
		sendToClientByInject(\$remote_socket, $msg);
		push @{$debug_showSpots_list{$ID}}, 1553;
	}
}

##
# visualDump(data [, label])
#
# Show the bytes in $data on screen as hexadecimal.
# Displays the label if provided.
sub visualDump {
	my ($msg, $label) = @_;
	my $dump;
	my $puncations = quotemeta '~!@#$%^&*()_+|\"\'';

	my $labelStr = $label ? " ($label)" : '';
	$dump = "================================================\n" .
		getFormattedDate(int(time)) . "\n\n" .
		length($msg) . " bytes$labelStr\n\n";

	for (my $i = 0; $i < length($msg); $i += 16) {
		my $line;
		my $data = substr($msg, $i, 16);
		my $rawData = '';

		for (my $j = 0; $j < length($data); $j++) {
			my $char = substr($data, $j, 1);

			if (($char =~ /\W/ && $char =~ /\S/ && !($char =~ /[$puncations]/))
			    || ($char eq chr(10) || $char eq chr(13) || $char eq "\t")) {
				$rawData .= '.';
			} else {
				$rawData .= substr($data, $j, 1);
			}
		}

		$line = getHex(substr($data, 0, 8));
		$line .= '    ' . getHex(substr($data, 8)) if (length($data) > 8);

		$line .= ' ' x (50 - length($line)) if (length($line) < 54);
		$line .= "    $rawData\n";
		$line = sprintf("%3d>  ", $i) . $line;
		$dump .= $line;
	}
	message $dump;
}


#######################################
#######################################
### CATEGORY: Field math
#######################################
#######################################

##
# calcRectArea($x, $y, $radius)
# Returns: an array with position hashes. Each has contains an x and a y key.
#
# Creates a rectangle with center ($x,$y) and radius $radius,
# and returns a list of positions of the border of the rectangle.
sub calcRectArea {
	my ($x, $y, $radius) = @_;
	my (%topLeft, %topRight, %bottomLeft, %bottomRight);

	sub capX {
		return 0 if ($_[0] < 0);
		return $field{width} - 1 if ($_[0] >= $field{width});
		return int $_[0];
	}
	sub capY {
		return 0 if ($_[0] < 0);
		return $field{height} - 1 if ($_[0] >= $field{height});
		return int $_[0];
	}

	# Get the avoid area as a rectangle
	$topLeft{x} = capX($x - $radius);
	$topLeft{y} = capY($y + $radius);
	$topRight{x} = capX($x + $radius);
	$topRight{y} = capY($y + $radius);
	$bottomLeft{x} = capX($x - $radius);
	$bottomLeft{y} = capY($y - $radius);
	$bottomRight{x} = capX($x + $radius);
	$bottomRight{y} = capY($y - $radius);

	# Walk through the border of the rectangle
	# Record the blocks that are walkable
	my @walkableBlocks;
	for (my $x = $topLeft{x}; $x <= $topRight{x}; $x++) {
		if (checkFieldWalkable(\%field, $x, $topLeft{y})) {
			push @walkableBlocks, {x => $x, y => $topLeft{y}};
		}
	}
	for (my $x = $bottomLeft{x}; $x <= $bottomRight{x}; $x++) {
		if (checkFieldWalkable(\%field, $x, $bottomLeft{y})) {
			push @walkableBlocks, {x => $x, y => $bottomLeft{y}};
		}
	}
	for (my $y = $bottomLeft{y} + 1; $y < $topLeft{y}; $y++) {
		if (checkFieldWalkable(\%field, $topLeft{x}, $y)) {
			push @walkableBlocks, {x => $topLeft{x}, y => $y};
		}
	}
	for (my $y = $bottomRight{y} + 1; $y < $topRight{y}; $y++) {
		if (checkFieldWalkable(\%field, $topLeft{x}, $y)) {
			push @walkableBlocks, {x => $topRight{x}, y => $y};
		}
	}

	return @walkableBlocks;
}

##
# calcRectArea2($x, $y, $radius, $minRange)
# Returns: an array with position hashes. Each has contains an x and a y key.
#
# Creates a rectangle with center ($x,$y) and radius $radius,
# and returns a list of positions inside the rectangle that are
# not closer than $minRange to the center.
sub calcRectArea2 {
	my ($cx, $cy, $r, $min) = @_;

	my @rectangle;
	for (my $x = $cx - $r; $x <= $cx + $r; $x++) {
		for (my $y = $cy - $r; $y <= $cy + $r; $y++) {
			next if distance({x => $cx, y => $cy}, {x => $x, y => $y}) < $min;
			push(@rectangle, {x => $x, y => $y});
		}
	}
	return @rectangle;
}

##
# checkFieldSnipable(r_field, x, y)
# r_field: a reference to a field hash.
# x, y: the coordinate to check.
# Returns: 1 (true) or 0 (false).
#
# Check whether you can snipe through ($x,$y) on field $r_field.
sub checkFieldSnipable {
	my $p = getFieldPoint(@_);
	return ($p == 0 || $p == 3 || $p == 5);
}

##
# checkFieldWalkable(r_field, x, y)
# r_field: a reference to a field hash.
# x, y: the coordinate to check.
# Returns: 1 (true) or 0 (false).
#
# Check whether ($x, $y) on field $r_field is walkable.
sub checkFieldWalkable {
	my $p = getFieldPoint(@_);
	return ($p == 0 || $p == 3);
}

##
# checkFieldWater(r_field, x, y)
# r_field: a reference to a field hash.
# x, y: the coordinate to check.
# Returns: 1 (true) or 0 (false).
#
# Check whether ($x, $y) on field $r_field is (walkable) water.
sub checkFieldWater {
	# FIXME: not implemented
	return 0;
}

##
# checkLineSnipable(from, to)
# from, to: references to position hashes.
#
# Check whether you can snipe a target standing at $to,
# from the position $from, without being blocked by any
# obstacles.
sub checkLineSnipable {
	my $from = shift;
	my $to = shift;
	my $min_obstacle_size = shift;
	$min_obstacle_size = 5 if (!defined $min_obstacle_size);

	my $dist = distance($from, $to);
	my %vec;

	getVector(\%vec, $to, $from);
	# Simulate walking from $from to $to
	for (my $i = 1; $i < $dist; $i++) {
		my %p;
		moveAlongVector(\%p, $from, \%vec, $i);
		$p{x} = int $p{x};
		$p{y} = int $p{y};
		return 0 if (!checkFieldSnipable(\%field, $p{x}, $p{y}));
	}
	return 1;
}

##
# checkLineWalkable(from, to, [min_obstacle_size = 5])
# from, to: references to position hashes.
#
# Check whether you can walk from $from to $to in an (almost)
# straight line, without obstacles that are too large.
# Obstacles are considered too large, if they are at least
# the size of a rectangle with "radius" $min_obstacle_size.
sub checkLineWalkable {
	my $from = shift;
	my $to = shift;
	my $min_obstacle_size = shift;
	$min_obstacle_size = 5 if (!defined $min_obstacle_size);

	my $dist = distance($from, $to);
	my %vec;

	getVector(\%vec, $to, $from);
	# Simulate walking from $from to $to
	for (my $i = 1; $i < $dist; $i++) {
		my %p;
		moveAlongVector(\%p, $from, \%vec, $i);
		$p{x} = int $p{x};
		$p{y} = int $p{y};

		if ( !checkFieldWalkable(\%field, $p{x}, $p{y}) ) {
			# The current spot is not walkable. Check whether
			# this the obstacle is small enough.
			if (checkWallLength(\%p, -1,  0, $min_obstacle_size) || checkWallLength(\%p,  1, 0, $min_obstacle_size)
			 || checkWallLength(\%p,  0, -1, $min_obstacle_size) || checkWallLength(\%p,  0, 1, $min_obstacle_size)
			 || checkWallLength(\%p, -1, -1, $min_obstacle_size) || checkWallLength(\%p,  1, 1, $min_obstacle_size)
			 || checkWallLength(\%p,  1, -1, $min_obstacle_size) || checkWallLength(\%p, -1, 1, $min_obstacle_size)) {
				return 0;
			}
		}
	}
	return 1;
}

sub checkWallLength {
	my $pos = shift;
	my $dx = shift;
	my $dy = shift;
	my $length = shift;

	my $x = $pos->{x};
	my $y = $pos->{y};
	my $len = 0;
	do {
		last if ($x < 0 || $x >= $field{width} || $y < 0 || $y >= $field{height});
		$x += $dx;
		$y += $dy;
		$len++;
	} while (!checkFieldWalkable(\%field, $x, $y) && $len < $length);
	return $len >= $length;
}

##
# closestWalkableSpot(r_field, pos)
# r_field: a reference to a field hash.
# pos: reference to a position hash (which contains 'x' and 'y' keys).
# Returns: 1 if %pos has been modified, 0 of not.
#
# If the position specified in $pos is walkable, this function will do nothing.
# If it's not walkable, this function will find the closest position that is walkable (up to 2 blocks away),
# and modify the x and y values in $pos.
sub closestWalkableSpot {
	my $r_field = shift;
	my $pos = shift;

	foreach my $z ( [0,0], [0,1],[1,0],[0,-1],[-1,0], [-1,1],[1,1],[1,-1],[-1,-1],[0,2],[2,0],[0,-2],[-2,0] ) {
		next if !checkFieldWalkable($r_field, $pos->{'x'} + $z->[0], $pos->{'y'} + $z->[1]);
		$pos->{x} += $z->[0];
		$pos->{y} += $z->[1];
		return 1;
	}
	return 0;
}

##
# getFieldPoint(r_field, x, y)
# r_field: a reference to a field hash.
# x, y: the coordinate on the field to check.
# Returns: An integer: 0 = walkable, 1 = not walkable, 3 = water (walkable), 5 = cliff (not walkable, but you can snipe)
#
# Get the raw value of the specified coordinate on the map. If you want to check whether
# ($x, $y) is walkable, use checkFieldWalkable instead.
sub getFieldPoint {
	my $r_field = shift;
	my $x = shift;
	my $y = shift;

	if ($x < 0 || $x >= $r_field->{width} || $y < 0 || $y >= $r_field->{height}) {
		return 1;
	}
	return ord(substr($r_field->{rawMap}, ($y * $r_field->{width}) + $x, 1));
}

##
# objectInsideSpell(object)
# object: reference to a player or monster hash.
#
# Checks whether an object is inside someone else's spell area.
# (Traps are also "area spells").
sub objectInsideSpell {
	my $object = shift;
	my ($x, $y) = ($object->{pos_to}{x}, $object->{pos_to}{y});
	foreach (@spellsID) {
		my $spell = $spells{$_};
		if ($spell->{sourceID} ne $accountID && $spell->{pos}{x} == $x && $spell->{pos}{y} == $y) {
			return 1;
		}
	}
	return 0;
}

##
# objectIsMovingTowards(object1, object2, [max_variance])
#
# Check whether $object1 is moving towards $object2.
sub objectIsMovingTowards {
	my $obj = shift;
	my $obj2 = shift;
	my $max_variance = (shift || 15);

	if (!timeOut($obj->{time_move}, $obj->{time_move_calc})) {
		# $obj is still moving
		my %vec;
		getVector(\%vec, $obj->{pos_to}, $obj->{pos});
		return checkMovementDirection($obj->{pos}, \%vec, $obj2->{pos_to}, $max_variance);
	}
	return 0;
}

##
# objectIsMovingTowardsPlayer(object, [ignore_party_members = 1])
#
# Check whether an object is moving towards a player.
sub objectIsMovingTowardsPlayer {
	my $obj = shift;
	my $ignore_party_members = shift;
	$ignore_party_members = 1 if (!defined $ignore_party_members);

	if (!timeOut($obj->{time_move}, $obj->{time_move_calc}) && @playersID) {
		# Monster is still moving, and there are players on screen
		my %vec;
		getVector(\%vec, $obj->{pos_to}, $obj->{pos});

		foreach (@playersID) {
			next if (!$_ || ($ignore_party_members &&
			                 ($char->{party} && $char->{party}{users}{$_}) ||
							 (existsInList($config{tankersList}, $players{$_}{name}) &&
							  $players{$_}{name} ne 'Unknown')));
			if (checkMovementDirection($obj->{pos}, \%vec, $players{$_}{pos}, 15)) {
				return 1;
			}
		}
	}
	return 0;
}

#######################################
#######################################
### CATEGORY: File Parsing and Writing
#######################################
#######################################

sub chatLog {
	my $type = shift;
	my $message = shift;
	open CHAT, ">> $Settings::chat_file";
	print CHAT "[".getFormattedDate(int(time))."][".uc($type)."] $message";
	close CHAT;
}

sub shopLog {
	my $crud = shift;
	open SHOPLOG, ">> $Settings::shop_log_file";
	print SHOPLOG "[".getFormattedDate(int(time))."] $crud";
	close SHOPLOG;
}

sub monsterLog {
	my $crud = shift;
	return if (!$config{'monsterLog'});
	open MONLOG, ">> $Settings::monster_log";
	print MONLOG "[".getFormattedDate(int(time))."] $crud\n";
	close MONLOG;
}

sub convertGatField {
	my $file = shift;
	my $r_hash = shift;
	my $i;
	open FILE, "+> $file";
	binmode(FILE);
	print FILE pack("S*", $$r_hash{'width'}, $$r_hash{'height'});
	print FILE $$r_hash{'rawMap'};
	close FILE;
}

##
# getField(name, r_field)
# name: the name of the field you want to load.
# r_field: reference to a hash, in which information about the field is stored.
# Returns: 1 on success, 0 on failure.
#
# Load a field (.fld) file. This function also loads an associated .dist file
# (the distance map file), which is used by pathfinding (for wall avoidance support).
# If the associated .dist file does not exist, it will be created.
#
# The r_field hash will contain the following keys:
# ~l
# - name: The name of the field. This is not always the same as baseName.
# - baseName: The name of the field, which is the base name of the file without the extension.
# - width: The field's width.
# - height: The field's height.
# - rawMap: The raw map data. Contains information about which blocks you can walk on (byte 0),
#    and which not (byte 1).
# - dstMap: The distance map data. Used by pathfinding.
# ~l~
sub getField {
	my ($name, $r_hash) = @_;
	my ($file, $dist_file);

	if ($name eq '') {
		error "Unable to load field file: no field name specified.\n";
		return 0;
	}

	undef %{$r_hash};
	$r_hash->{name} = $name;

	if ($masterServer && $masterServer->{"field_$name"}) {
		# Handle server-specific versions of the field.
		$file = "$Settings::def_field/" . $masterServer->{"field_$name"};
	} else {
		$file = "$Settings::def_field/$name.fld";
	}
	$file =~ s/\//\\/g if ($^O eq 'MSWin32');
	$dist_file = $file;

	unless (-e $file) {
		my %aliases = (
			'new_1-1.fld' => 'new_zone01.fld',
			'new_2-1.fld' => 'new_zone01.fld',
			'new_3-1.fld' => 'new_zone01.fld',
			'new_4-1.fld' => 'new_zone01.fld',
			'new_5-1.fld' => 'new_zone01.fld',

			'new_1-2.fld' => 'new_zone02.fld',
			'new_2-2.fld' => 'new_zone02.fld',
			'new_3-2.fld' => 'new_zone02.fld',
			'new_4-2.fld' => 'new_zone02.fld',
			'new_5-2.fld' => 'new_zone02.fld',

			'new_1-3.fld' => 'new_zone03.fld',
			'new_2-3.fld' => 'new_zone03.fld',
			'new_3-3.fld' => 'new_zone03.fld',
			'new_4-3.fld' => 'new_zone03.fld',
			'new_5-3.fld' => 'new_zone03.fld',

			'new_1-4.fld' => 'new_zone04.fld',
			'new_2-4.fld' => 'new_zone04.fld',
			'new_3-4.fld' => 'new_zone04.fld',
			'new_4-4.fld' => 'new_zone04.fld',
			'new_5-4.fld' => 'new_zone04.fld',
		);

		my ($dir, $base) = $file =~ /^(.*[\\\/])?(.*)$/;
		if (exists $aliases{$base}) {
			$file = "${dir}$aliases{$base}";
			$dist_file = $file;
		}

		if (! -e $file) {
			warning "Could not load field $file - you must install the kore-field pack!\n";
			return 0;
		}
	}

	$dist_file =~ s/\.fld$/.dist/i;
	$r_hash->{baseName} = $file;
	$r_hash->{baseName} =~ s/.*[\\\/]//;
	$r_hash->{baseName} =~ s/(.*)\..*/$1/;

	# Load the .fld file
	open FILE, "< $file";
	binmode(FILE);
	my $data;
	{
		local($/);
		$data = <FILE>;
		close FILE;
		@$r_hash{'width', 'height'} = unpack("S1 S1", substr($data, 0, 4, ''));
		$r_hash->{rawMap} = $data;
	}

	# Load the associated .dist file (distance map)
	if (-e $dist_file) {
		open FILE, "< $dist_file";
		binmode(FILE);
		my $dist_data;

		{
			local($/);
			$dist_data = <FILE>;
		}
		close FILE;
		my $dversion = 0;
		if (substr($dist_data, 0, 2) eq "V#") {
			$dversion = unpack("xx S1", substr($dist_data, 0, 4, ''));
		}

		my ($dw, $dh) = unpack("S1 S1", substr($dist_data, 0, 4, ''));
		if (
			#version 0 files had a bug when height != width
			#version 1 files did not treat walkable water as walkable, all version 0 and 1 maps need to be rebuilt
			#version 2 and greater have no know bugs, so just do a minimum validity check.
			$dversion >= 2 && $$r_hash{'width'} == $dw && $$r_hash{'height'} == $dh
		) {
			$r_hash->{dstMap} = $dist_data;
		}
	}

	# The .dist file is not available; create it
	unless ($r_hash->{dstMap}) {
		$r_hash->{dstMap} = makeDistMap($r_hash->{rawMap}, $r_hash->{width}, $r_hash->{height});
		open FILE, "> $dist_file" or die "Could not write dist cache file: $!\n";
		binmode(FILE);
		print FILE pack("a2 S1", 'V#', 2);
		print FILE pack("S1 S1", @$r_hash{'width', 'height'});
		print FILE $r_hash->{dstMap};
		close FILE;
	}

	return 1;
}

sub getGatField {
	my $file = shift;
	my $r_hash = shift;
	my ($i, $data);
	undef %{$r_hash};
	($$r_hash{'name'}) = $file =~ /([\s\S]*)\./;
	open FILE, $file;
	binmode(FILE);
	read(FILE, $data, 16);
	my $width = unpack("L1", substr($data, 6,4));
	my $height = unpack("L1", substr($data, 10,4));
	$$r_hash{'width'} = $width;
	$$r_hash{'height'} = $height;
	while (read(FILE, $data, 20)) {
		$$r_hash{'rawMap'} .= substr($data, 14, 1);
		$i++;
	}
	close FILE;
}


#########################################
#########################################
### CATEGORY: Logging
#########################################
#########################################

sub itemLog {
	my $crud = shift;
	return if (!$config{'itemHistory'});
	open ITEMLOG, ">> $Settings::item_log_file";
	print ITEMLOG "[".getFormattedDate(int(time))."] $crud";
	close ITEMLOG;
}

#########################################
#########################################
### CATEGORY: Operating system specific
#########################################
#########################################


##
# launchURL(url)
#
# Open $url in the operating system's preferred web browser.
sub launchURL {
	my $url = shift;

	if ($^O eq 'MSWin32') {
		require WinUtils;
		WinUtils::ShellExecute(0, undef, $url);

	} else {
		my $mod = 'use POSIX;';
		eval $mod;

		# This is a script I wrote for the autopackage project
		# It autodetects the current desktop environment
		my $detectionScript = <<"		EOF";
			function detectDesktop() {
				if [[ "\$DISPLAY" = "" ]]; then
                			return 1
				fi

				local LC_ALL=C
				local clients
				if ! clients=`xlsclients`; then
			                return 1
				fi

				if echo "\$clients" | grep -qE '(gnome-panel|nautilus|metacity)'; then
					echo gnome
				elif echo "\$clients" | grep -qE '(kicker|slicker|karamba|kwin)'; then
        			        echo kde
				else
        			        echo other
				fi
				return 0
			}
			detectDesktop
		EOF

		my ($r, $w, $desktop);
		my $pid = IPC::Open2::open2($r, $w, '/bin/bash');
		print $w $detectionScript;
		close $w;
		$desktop = <$r>;
		$desktop =~ s/\n//;
		close $r;
		waitpid($pid, 0);

		sub checkCommand {
			foreach (split(/:/, $ENV{PATH})) {
				return 1 if (-x "$_/$_[0]");
			}
			return 0;
		}

		if ($desktop eq "gnome" && checkCommand('gnome-open')) {
			launchApp(1, 'gnome-open', $url);

		} elsif ($desktop eq "kde") {
			launchApp(1, 'kfmclient', 'exec', $url);

		} else {
			if (checkCommand('firefox')) {
				launchApp(1, 'firefox', $url);
			} elsif (checkCommand('mozillaa')) {
				launchApp(1, 'mozilla', $url);
			} else {
				$interface->errorDialog("No suitable browser detected. " .
					"Please launch your favorite browser and go to:\n$url");
			}
		}
	}
}


#######################################
#######################################
### CATEGORY: Other functions
#######################################
#######################################


sub avoidGM_talk {
	return 0 if ($xkore || !$config{avoidGM_talk});
	my ($user, $msg) = @_;

	# Check whether this "GM" is on the ignore list
	# in order to prevent false matches
	my $j = 0;
	while ($config{"avoid_ignore_$j"} ne "") {
		if ($user eq $config{"avoid_ignore_$j"}) {
			return 0;
		}
		$j++;
	}

	if ($user =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i || $user =~ /$config{avoidGM_namePattern}/) {
		my %args = (
			name => $user,
		);
		Plugins::callHook('avoidGM_talk', \%args);
		return 1 if ($args{return});

		warning "Disconnecting to avoid GM!\n";
		main::chatLog("k", "*** The GM $user talked to you, auto disconnected ***\n");

		my $tmp = $config{avoidGM_reconnect};
		warning "Disconnect for $tmp seconds...\n";
		$timeout_ex{master}{time} = time;
		$timeout_ex{master}{timeout} = $tmp;
		Network::disconnect(\$remote_socket);
		return 1;
	}
	return 0;
}

sub avoidList_talk {
	return 0 if ($xkore || !$config{avoidList});
	my ($user, $msg, $ID) = @_;

	if ($avoid{Players}{lc($user)}{disconnect_on_chat} || $avoid{ID}{$ID}{disconnect_on_chat}) {
		warning "Disconnecting to avoid $user!\n";
		main::chatLog("k", "*** $user talked to you, auto disconnected ***\n");
		warning "Disconnect for $config{avoidList_reconnect} seconds...\n";
		$timeout_ex{master}{time} = time;
		$timeout_ex{master}{timeout} = $config{avoidList_reconnect};
		Network::disconnect(\$remote_socket);
		return 1;
	}
	return 0;
}

sub calcStat {
	my $damage = shift;
    $totaldmg += $damage;
}

##
# center(string, width, [fill])
#
# This function will center $string within a field $width characters wide,
# using $fill characters for padding on either end of the string for
# centering. If $fill is not specified, a space will be used.
sub center {
	my ($string, $width, $fill) = @_;

	$fill ||= ' ';
	my $left = int(($width - length($string)) / 2);
	my $right = ($width - length($string)) - $left;
	return $fill x $left . $string . $fill x $right;
}

# Returns: 0 if user chose to quit, 1 if user chose a character, 2 if user created or deleted a character
sub charSelectScreen {
	my %plugin_args = (autoLogin => shift);
	my $msg;
	my $mode;
	my $input2;

	TOP: {
		undef $mode;
		undef $input2;
		undef $msg;
	}

	for (my $num = 0; $num < @chars; $num++) {
		next unless ($chars[$num] && %{$chars[$num]});
		if (0) {
		$msg .= swrite(
			"-------  Character @< ---------",
			[$num],
			"Name: @<<<<<<<<<<<<<<<<<<<<<<<<",
			[$chars[$num]{'name'}],
			"Job:  @<<<<<<<      Job Exp: @<<<<<<<",
			[$jobs_lut{$chars[$num]{'jobID'}}, $chars[$num]{'exp_job'}],
			"Lv:   @<<<<<<<      Str: @<<<<<<<<",
			[$chars[$num]{'lv'}, $chars[$num]{'str'}],
			"J.Lv: @<<<<<<<      Agi: @<<<<<<<<",
			[$chars[$num]{'lv_job'}, $chars[$num]{'agi'}],
			"Exp:  @<<<<<<<      Vit: @<<<<<<<<",
			[$chars[$num]{'exp'}, $chars[$num]{'vit'}],
			"HP:   @||||/@||||   Int: @<<<<<<<<",
			[$chars[$num]{'hp'}, $chars[$num]{'hp_max'}, $chars[$num]{'int'}],
			"SP:   @||||/@||||   Dex: @<<<<<<<<",
			[$chars[$num]{'sp'}, $chars[$num]{'sp_max'}, $chars[$num]{'dex'}],
			"Zenny: @<<<<<<<<<<  Luk: @<<<<<<<<",
			[$chars[$num]{'zenny'}, $chars[$num]{'luk'}],
			"-------------------------------", []);
		}
		$msg .= sprintf("%3s %-34s %-15s %2d/%2d\n",
			$num, $chars[$num]{name},
			$jobs_lut{$chars[$num]{'jobID'}},
			$chars[$num]{lv}, $chars[$num]{lv_job});
	}

	if ($msg) {
		message
			"---------------------- Character List ----------------------\n".
			sprintf("%3s %-34s %-15s %-6s\n", '#', 'Name', 'Job', 'Lv') .
			$msg .
			"------------------------------------------------------------\n",
			"connection";
	}
	return 1 if $xkore;

	Plugins::callHook('charSelectScreen', \%plugin_args);
	return $plugin_args{return} if ($plugin_args{return});

	if ($plugin_args{autoLogin} && @chars && $config{'char'} ne "" && $chars[$config{'char'}]) {
		sendCharLogin(\$remote_socket, $config{'char'});
		$timeout{'charlogin'}{'time'} = time;
		return 1;
	}


	if (@chars) {
		message("Type 'c' to create a new character, or type 'd' to delete a character.\n" .
			"Or choose a character by entering its number.\n", "input");
		while (!$quit) {
			my $input = $interface->getInput(-1);
			next if (!defined $input);

			my @args = parseArgs($input);

			if ($args[0] eq "c") {
				$mode = "create";
				($input2) = $input =~ /^.*? +(.*)/;
				last;
			} elsif ($args[0] eq "d") {
				$mode = "delete";
				($input2) = $input =~ /^.*? +(.*)/;
				last;
			} elsif ($args[0] eq "quit") {
				quit();
				return 0;
			} elsif ($input !~ /^\d+$/) {
				error "\"$input\" is not a valid character number.\n";
			} elsif (!$chars[$input]) {
				error "Character #$input does not exist.\n";
			} else {
				configModify('char', $input, 1);
				sendCharLogin(\$remote_socket, $config{'char'});
				$timeout{'charlogin'}{'time'} = time;
				return 1;
			}
		}
	} else {
		message("There are no characters on this account.\n", "connection");
		$mode = "create";
	}

	if ($mode eq "create") {
		my $message = "Please enter the desired properties for your characters, in this form:\n" .
				"(slot) \"(name)\" [(str) (agi) (vit) (int) (dex) (luk) [(hairstyle) [(haircolor)]]]\n";
		message($message, "input") if ($input2 eq "");

		while (!$quit) {
			my $input;
			if ($input2 ne "") {
				$input = $input2;
				undef $input2;
			} else {
				$input = $interface->getInput(-1);
			}
			next if (!defined $input);
			if ($input eq "quit") {
				if (@chars) {
					goto TOP;
				} else {
					quit();
					last;
				}
			}

			my @args = parseArgs($input);
			if (@args < 2) {
				error $message;
				next;
			}

			message "Creating character \"$args[1]\" in slot \"$args[0]\"...\n", "connection";
			$timeout{'charlogin'}{'time'} = time;
			last if (createCharacter(@args));
			message($message, "input");
		}

	} elsif ($mode eq "delete") {
		my $message = "Enter the number of the character you want to delete, and your email,\n" .
				"in this form: (slot) (email address)\n";
		message $message, "input";

		while (!$quit) {
			my $input;
			if ($input2 ne "") {
				$input = $input2;
				undef $input2;
			} else {
				$input = $interface->getInput(-1);
			}
			next if (!defined $input);
			goto TOP if ($input eq "quit");

			my @args = parseArgs($input);
			if (@args < 2) {
				error $message;
				next;
			} elsif ($args[0] !~ /^\d+/) {
				error "\"$args[0]\" is not a valid character number.\n";
				next;
			} elsif (!$chars[$args[0]]) {
				error "Character #$args[0] does not exist.\n";
				next;
			}

			warning "Are you ABSOLUTELY SURE you want to delete $chars[$args[0]]{name} ($args[0])? (y/n) ";
			$input = $interface->getInput(-1);
			if ($input eq "y") {
				sendCharDelete(\$remote_socket, $chars[$args[0]]{ID}, $args[1]);
				message "Deleting character $chars[$args[0]]{name}...\n", "connection";
				$AI::temp::delIndex = $args[0];
			} else {
				message "Deletion aborted\n", "info";
				goto TOP;
			}
			$timeout{'charlogin'}{'time'} = time;
			last;
		}
	}
	return 2;
}

sub chatLog_clear {
	if (-f $Settings::chat_file) { unlink($Settings::chat_file); }
}

##
# checkAllowedMap($map)
#
# Checks whether $map is in $config{allowedMaps}.
# Disconnects if it is not, and $config{allowedMaps_reaction} != 0.
sub checkAllowedMap {
	my $map = shift;

	return unless $AI;
	return unless $config{allowedMaps};
	return if existsInList($config{allowedMaps}, $map);
	return if $config{allowedMaps_reaction} == 0;

	warning "The current map ($map) is not on the list of allowed maps.\n";
	main::chatLog("k", "** The current map ($map) is not on the list of allowed maps.\n");
	main::chatLog("k", "** Exiting...\n");
	quit();
}

##
# checkFollowMode()
# Returns: 1 if in follow mode, 0 if not.
#
# Check whether we're current in follow mode.
sub checkFollowMode {
	my $followIndex;
	if ($config{follow} && defined($followIndex = binFind(\@ai_seq, "follow"))) {
		return 1 if ($ai_seq_args[$followIndex]{following});
	}
	return 0;
}

##
# checkMonsterCleanness(ID)
# ID: the monster's ID.
#
# Checks whether a monster is "clean" (not being attacked by anyone).
sub checkMonsterCleanness {
	return 1 if (!$config{attackAuto});
	my $ID = shift;
	my $monster = $monsters{$ID};

	# If party attacked monster, or if monster attacked/missed party
	if ($monster->{'dmgFromParty'} > 0 || $monster->{'dmgToParty'} > 0 || $monster->{'missedToParty'} > 0) {
		return 1;
	}

	# If we're in follow mode
	if (defined(my $followIndex = binFind(\@ai_seq, "follow"))) {
		my $following = $ai_seq_args[$followIndex]{following};
		my $followID = $ai_seq_args[$followIndex]{ID};

		if ($following) {
			# And master attacked monster, or the monster attacked/missed master
			if ($monster->{dmgToPlayer}{$followID} > 0
			 || $monster->{missedToPlayer}{$followID} > 0
			 || $monster->{dmgFromPlayer}{$followID} > 0) {
				return 1;
			}
		}
	}

	# If monster attacked/missed you
	return 1 if ($monster->{'dmgToYou'} || $monster->{'missedYou'});

	# If monster hasn't been attacked by other players
	if (!binSize([keys %{$monster->{'missedFromPlayer'}}])
	 && !binSize([keys %{$monster->{'dmgFromPlayer'}}])
	 && !binSize([keys %{$monster->{'castOnByPlayer'}}])

	 # and it hasn't attacked any other player
	 && !binSize([keys %{$monster->{'missedToPlayer'}}])
	 && !binSize([keys %{$monster->{'dmgToPlayer'}}])
	 && !binSize([keys %{$monster->{'castOnToPlayer'}}])
	) {
		# The monster might be getting lured by another player.
		# So we check whether it's walking towards any other player, but only
		# if we haven't already attacked the monster.
		if ($monster->{'dmgFromYou'} || $monster->{'missedFromYou'}) {
			return 1;
		} else {
			return !objectIsMovingTowardsPlayer($monster);
		}
	}

	# The monster didn't attack you.
	# Other players attacked it, or it attacked other players.
	if ($monster->{'dmgFromYou'} || $monster->{'missedFromYou'}) {
		# If you have already attacked the monster before, then consider it clean
		return 1;
	}
	# If you haven't attacked the monster yet, it's unclean.

	return 0;
}

##
# createCharacter(slot, name, [str,agi,vit,int,dex,luk] = 5)
# slot: the slot in which to create the character (1st slot is 0).
# name: the name of the character to create.
#
# Create a new character. You must be currently connected to the character login server.
sub createCharacter {
	my $slot = shift;
	my $name = shift;
	my ($str,$agi,$vit,$int,$dex,$luk, $hair_style, $hair_color) = @_;

	if (!@_) {
		($str,$agi,$vit,$int,$dex,$luk) = (5,5,5,5,5,5);
	}

	if ($conState != 3) {
		error "We're not currently connected to the character login server.\n";
	} elsif ($slot !~ /^\d+$/) {
		error "Slot \"$slot\" is not a valid number.\n";
	} elsif ($slot < 0 || $slot > 4) {
		error "The slot must be comprised between 0 and 2\n";
	} elsif ($chars[$slot]) {
		error "Slot $slot already contains a character ($chars[$slot]{name}).\n";
	} elsif (length($name) > 23) {
		error "Name must not be longer than 23 characters\n";

	} else {
		for ($str,$agi,$vit,$int,$dex,$luk) {
			if ($_ > 9 || $_ < 1) {
				error "Stats must be comprised between 1 and 9\n";
				return;
			}
		}
		for ($str+$int, $agi+$luk, $vit+$dex) {
			if ($_ != 10) {
				error "The sums Str + Int, Agi + Luk and Vit + Dex must all be equal to 10\n" ;
				return;
			}
		}

		sendCharCreate(\$remote_socket, $slot, $name,
			$str, $agi, $vit, $int, $dex, $luk,
			$hair_style, $hair_color);
		return 1;
	}
}

##
# deal($player)
#
# Sends $player a deal request.
sub deal {
	my ($player) = @_;

	$outgoingDeal{ID} = $player->{ID};
	sendDeal($player->{ID});
}

##
# dealAddItem($item, $amount)
#
# Adds $amount of $item to the current deal.
sub dealAddItem {
	my ($item, $amount) = @_;

	sendDealAddItem($item->{index}, $amount);
	$currentDeal{lastItemAmount} = $amount;
}

##
# drop(item, amount)
#
# Drops $amount of $item. If $amount is not specified or too large, it defaults
# to the number of $item you have.
sub drop {
	my ($item, $amount) = @_;

	if (!$amount || $amount > $char->{inventory}[$item]{amount}) {
		$amount = $char->{inventory}[$item]{amount};
	}
	sendDrop(\$remote_socket, $char->{inventory}[$item]{index}, $amount);
}

sub dumpData {
	my $msg = shift;
	my $silent = shift;
	my $dump;
	my $puncations = quotemeta '~!@#$%^&*()_+|\"\'';

	$dump = "\n\n================================================\n" .
		getFormattedDate(int(time)) . "\n\n" .
		length($msg) . " bytes\n\n";

	for (my $i = 0; $i < length($msg); $i += 16) {
		my $line;
		my $data = substr($msg, $i, 16);
		my $rawData = '';

		for (my $j = 0; $j < length($data); $j++) {
			my $char = substr($data, $j, 1);

			if (($char =~ /\W/ && $char =~ /\S/ && !($char =~ /[$puncations]/))
			    || ($char eq chr(10) || $char eq chr(13) || $char eq "\t")) {
				$rawData .= '.';
			} else {
				$rawData .= substr($data, $j, 1);
			}
		}

		$line = getHex(substr($data, 0, 8));
		$line .= '    ' . getHex(substr($data, 8)) if (length($data) > 8);

		$line .= ' ' x (50 - length($line)) if (length($line) < 54);
		$line .= "    $rawData\n";
		$line = sprintf("%3d>  ", $i) . $line;
		$dump .= $line;
	}

	open DUMP, ">> DUMP.txt";
	print DUMP $dump;
	close DUMP;

	debug "$dump\n", "parseMsg", 2;
	message "Message Dumped into DUMP.txt!\n", undef, 1 unless ($silent);
}

sub getIDFromChat {
	my $r_hash = shift;
	my $msg_user = shift;
	my $match_text = shift;
	my $qm;
	if ($match_text !~ /\w+/ || $match_text eq "me" || $match_text eq "") {
		foreach (keys %{$r_hash}) {
			next if ($_ eq "");
			if ($msg_user eq $r_hash->{$_}{name}) {
				return $_;
			}
		}
	} else {
		foreach (keys %{$r_hash}) {
			next if ($_ eq "");
			$qm = quotemeta $match_text;
			if ($r_hash->{$_}{name} =~ /$qm/i) {
				return $_;
			}
		}
	}
	return undef;
}

sub getPortalDestName {
	my $ID = shift;
	my %hash; # We only want unique names, so we use a hash
	foreach (keys %{$portals_lut{$ID}{'dest'}}) {
		my $key = $portals_lut{$ID}{'dest'}{$_}{'map'};
		$hash{$key} = 1;
	}

	my @destinations = sort keys %hash;
	return join('/', @destinations);
}

sub getResponse {
	my $type = quotemeta shift;

	my @keys;
	foreach my $key (keys %responses) {
		if ($key =~ /^$type\_\d+$/) {
			push @keys, $key;
		}
	}

	my $msg = $responses{$keys[int(rand(@keys))]};
	$msg =~ s/\%\$(\w+)/$responseVars{$1}/eig;
	return $msg;
}

sub getSpellName {
	my $spell = shift;
	return $spells_lut{$spell} || "Unknown $spell";
}

##
# inInventory($item, $quantity = 1)
#
# Returns $index (can be 0!) if you have at least $quantity units of $item in
# your inventory.
# Returns nothing otherwise.
sub inInventory {
	my ($item, $quantity) = @_;
	$quantity ||= 1;

	my $index = findIndexString_lc($char->{inventory}, 'name', $item);
	return if $index eq '';
	return unless $char->{inventory}[$index]{amount} >= $quantity;
	return $index;
}

##
# inventoryItemRemoved($invIndex, $amount)
#
# Removes $amount of $invIndex from $char->{inventory}.
# Also prints a message saying the item was removed (unless it is an arrow you
# fired).
sub inventoryItemRemoved {
	my ($invIndex, $amount) = @_;

	my $item = $char->{inventory}[$invIndex];
	if (!$char->{arrow} ||
	    $char->{arrow} != $char->{inventory}[$invIndex]{index}) {
		# This item is not an equipped arrow
		message "Inventory Item Removed: $item->{name} ($invIndex) x $amount\n", "inventory";
	}
	$item->{amount} -= $amount;
	delete $char->{inventory}[$invIndex] if $item->{amount} <= 0;
	$itemChange{$item->{name}} -= $amount;
}

# Resolve the name of a card
sub cardName {
	my $cardID = shift;

	# If card name is unknown, just return ?number
	my $card = $items_lut{$cardID};
	return "?$cardID" if !$card;
	$card =~ s/ Card$//;
	return $card;
}

# Resolve the name of a simple item
sub itemNameSimple {
	my $ID = shift;
	return 'Unknown' unless defined($ID);
	return 'None' unless $ID;
	return $items_lut{$ID} || "Unknown #$ID";
}

##
# itemName($item)
#
# Resolve the name of an item. $item should be a hash with these keys:
# nameID  => integer index into %items_lut
# cards   => 8-byte binary data as sent by server
# upgrade => integer upgrade level
sub itemName {
	my $item = shift;

	my $name = itemNameSimple($item->{nameID});

	# Resolve item prefix/suffix (carded or forged)
	my $prefix = "";
	my $suffix = "";
	my @cards;
	my %cards;
	for (my $i = 0; $i < 4; $i++) {
		my $card = unpack("S1", substr($item->{cards}, $i*2, 2));
		last unless $card;
		push(@cards, $card);
		($cards{$card} ||= 0) += 1;
	}
	if ($cards[0] == 254) {
		# Alchemist-made potion
		#
		# Ignore the "cards" inside.
	} elsif ($cards[0] == 255) {
		# Forged weapon
		#
		# Display e.g. "VVS Earth" or "Fire"
		my $elementID = $cards[1] % 10;
		my $elementName = $elements_lut{$elementID};
		my $starCrumbs = ($cards[1] >> 8) / 5;
		$prefix .= ('V'x$starCrumbs)."S " if $starCrumbs;
		$prefix .= "$elementName " if ($elementName ne "");
	} elsif (@cards) {
		# Carded item
		#
		# List cards in alphabetical order.
		# Stack identical cards.
		# e.g. "Hydra*2,Mummy*2", "Hydra*3,Mummy"
		$suffix = join(',', map {
			cardName($_).($cards{$_} > 1 ? "*$cards{$_}" : '')
		} sort { cardName($a) cmp cardName($b) } keys %cards);
	}

	my $numSlots = $itemSlotCount_lut{$item->{nameID}} if ($prefix eq "");

	my $display = "";
	$display .= "BROKEN " if $item->{broken};
	$display .= "+$item->{upgrade} " if $item->{upgrade};
	$display .= $prefix if $prefix;
	$display .= $name;
	$display .= " [$suffix]" if $suffix;
	$display .= " [$numSlots]" if $numSlots;

	return $display;
}

##
# storageGet(items, max)
# items: reference to an array of storage item hashes.
# max: the maximum amount to get, for each item, or 0 for unlimited.
#
# Get one or more items from storage.
#
# Example:
# # Get items $a and $b from storage.
# storageGet([$a, $b]);
# # Get items $a and $b from storage, but at most 30 of each item.
# storageGet([$a, $b], 30);
sub storageGet {
	my $indices = shift;
	my $max = shift;

	if (@{$indices} == 1) {
		my ($item) = @{$indices};
		if (!defined($max) || $max > $item->{amount}) {
			$max = $item->{amount};
		}
		sendStorageGet($item->{index}, $max);

	} else {
		my %args;
		$args{items} = $indices;
		$args{max} = $max;
		$args{timeout} = 0.15;
		AI::queue("storageGet", \%args);
	}
}

##
# headgearName(lookID)
#
# Resolves a lookID of a headgear into a human readable string.
#
# A lookID corresponds to a line number in tables/headgears.txt.
# The number on that line is the itemID for the headgear.
sub headgearName {
	my ($lookID) = @_;

	return "Nothing" if $lookID == 0;

	my $itemID = $headgears_lut[$lookID];

	if (!defined($itemID)) {
		return "Unknown lookID $lookID";
	}

	return main::itemName({nameID => $itemID});
}

sub itemLog_clear {
	if (-f $Settings::item_log_file) { unlink($Settings::item_log_file); }
}

##
# look(bodydir, [headdir])
# bodydir: a number 0-7. See directions.txt.
# headdir: 0 = look directly, 1 = look right, 2 = look left
#
# Look in the given directions.
sub look {
	my %args = (
		look_body => shift,
		look_head => shift
	);
	AI::queue("look", \%args);
}

##
# lookAtPosition(pos, [headdir])
# pos: a reference to a coordinate hash.
# headdir: 0 = face directly, 1 = look right, 2 = look left
#
# Turn face and body direction to position %pos.
sub lookAtPosition {
	my $pos2 = shift;
	my $headdir = shift;
	my %vec;
	my $direction;

	getVector(\%vec, $pos2, $char->{pos_to});
	$direction = int(sprintf("%.0f", (360 - vectorToDegree(\%vec)) / 45)) % 8;
	look($direction, $headdir);
}

##
# manualMove(dx, dy)
#
# Moves the character offset from its current position.
sub manualMove {
	my ($dx, $dy) = @_;

	# Stop following if necessary
	if ($config{'follow'}) {
		configModify('follow', 0);
		AI::clear('follow');
	}

	# Stop moving if necessary
	AI::clear(qw/move route mapRoute/);
	main::ai_route($field{name}, $char->{pos_to}{x} + $dx, $char->{pos_to}{y} + $dy);
}

sub objectAdded {
	my ($type, $ID, $obj) = @_;

	if ($type eq 'player' || $type eq 'npc') {
		push @unknownObjects, $ID;
	}

	if ($type eq 'monster') {
		if (mon_control($obj->{name})->{teleport_search}) {
			$ai_v{temp}{searchMonsters}++;
		}
	}

	Plugins::callHook('objectAdded', {
		type => $type,
		ID => $ID,
		obj => $obj
	});
}

sub objectRemoved {
	my ($type, $ID, $obj) = @_;

	if ($type eq 'monster') {
		if (mon_control($obj->{name})->{teleport_search}) {
			$ai_v{temp}{searchMonsters}--;
		}
	}

	Plugins::callHook('objectRemoved', {
		type => $type,
		ID => $ID
	});
}

##
# items_control($name)
#
# Returns the items_control.txt settings for monster name $name.
# If $name has no specific settings, use 'all'.
sub items_control {
	my ($name) = @_;

	return $items_control{lc($name)} || $items_control{all} || {};
}

##
# mon_control($name)
#
# Returns the mon_control.txt settings for monster name $name.
# If $name has no specific settings, use 'all'.
sub mon_control {
	my ($name) = @_;

	return $mon_control{lc($name)} ||
		$mon_control{all} ||
		{ attack_auto => 1 };
}

sub positionNearPlayer {
	my $r_hash = shift;
	my $dist = shift;

	foreach (@playersID) {
		next unless defined $_;
		next if $char->{party} && $char->{party}{users} &&
			$char->{party}{users}{$_};
		next if existsInList($config{tankersList}, $players{$_}{name});
		return 1 if (distance($r_hash, $players{$_}{pos_to}) <= $dist);
	}
	return 0;
}

sub positionNearPortal {
	my $r_hash = shift;
	my $dist = shift;

	foreach (@portalsID) {
		next unless defined $_;
		return 1 if (distance($r_hash, $portals{$_}{pos}) <= $dist);
	}
	return 0;
}

##
# printItemDesc(itemID)
#
# Print the description for $itemID.
sub printItemDesc {
	my $itemID = shift;
	message("===============Item Description===============\n", "info");
	message("Item: $items_lut{$itemID}\n\n", "info");
	message($itemsDesc_lut{$itemID}, "info");
	message("==============================================\n", "info");
}

sub quit {
	$quit = 1;
	message "Exiting...\n", "system";
}

sub relog {
	my $timeout = (shift || 5);
	$conState = 1;
	undef $conState_tries;
	$timeout_ex{'master'}{'time'} = time;
	$timeout_ex{'master'}{'timeout'} = $timeout;
	Network::disconnect(\$remote_socket);
	message "Relogging in $timeout seconds...\n", "connection";
}

sub sendMessage {
	my $r_socket = shift;
	my $type = shift;
	my $msg = shift;
	my $user = shift;
	my ($i, $j);
	my @msg;
	my @msgs;
	my $oldmsg;
	my $amount;
	my $space;
	@msgs = split /\\n/,$msg;
	for ($j = 0; $j < @msgs; $j++) {
		@msg = split / /, $msgs[$j];
		undef $msg;
		for ($i = 0; $i < @msg; $i++) {
			if (!length($msg[$i])) {
				$msg[$i] = " ";
				$space = 1;
			}
			if (length($msg[$i]) > $config{'message_length_max'}) {
				while (length($msg[$i]) >= $config{'message_length_max'}) {
					$oldmsg = $msg;
					if (length($msg)) {
						$amount = $config{'message_length_max'};
						if ($amount - length($msg) > 0) {
							$amount = $config{'message_length_max'} - 1;
							$msg .= " " . substr($msg[$i], 0, $amount - length($msg));
						}
					} else {
						$amount = $config{'message_length_max'};
						$msg .= substr($msg[$i], 0, $amount);
					}
					if ($type eq "c") {
						sendChat($r_socket, $msg);
					} elsif ($type eq "g") {
						sendGuildChat($r_socket, $msg);
					} elsif ($type eq "p") {
						sendPartyChat($r_socket, $msg);
					} elsif ($type eq "pm") {
						sendPrivateMsg($r_socket, $user, $msg);
						undef %lastpm;
						$lastpm{'msg'} = $msg;
						$lastpm{'user'} = $user;
						push @lastpm, {%lastpm};
					} elsif ($type eq "k" && $xkore) {
						injectMessage($msg);
	 				}
					$msg[$i] = substr($msg[$i], $amount - length($oldmsg), length($msg[$i]) - $amount - length($oldmsg));
					undef $msg;
				}
			}
			if (length($msg[$i]) && length($msg) + length($msg[$i]) <= $config{'message_length_max'}) {
				if (length($msg)) {
					if (!$space) {
						$msg .= " " . $msg[$i];
					} else {
						$space = 0;
						$msg .= $msg[$i];
					}
				} else {
					$msg .= $msg[$i];
				}
			} else {
				if ($type eq "c") {
					sendChat($r_socket, $msg);
				} elsif ($type eq "g") {
					sendGuildChat($r_socket, $msg);
				} elsif ($type eq "p") {
					sendPartyChat($r_socket, $msg);
				} elsif ($type eq "pm") {
					sendPrivateMsg($r_socket, $user, $msg);
					undef %lastpm;
					$lastpm{'msg'} = $msg;
					$lastpm{'user'} = $user;
					push @lastpm, {%lastpm};
				} elsif ($type eq "k" && $xkore) {
					injectMessage($msg);
				}
				$msg = $msg[$i];
			}
			if (length($msg) && $i == @msg - 1) {
				if ($type eq "c") {
					sendChat($r_socket, $msg);
				} elsif ($type eq "g") {
					sendGuildChat($r_socket, $msg);
				} elsif ($type eq "p") {
					sendPartyChat($r_socket, $msg);
				} elsif ($type eq "pm") {
					sendPrivateMsg($r_socket, $user, $msg);
					undef %lastpm;
					$lastpm{'msg'} = $msg;
					$lastpm{'user'} = $user;
					push @lastpm, {%lastpm};
				} elsif ($type eq "k" && $xkore) {
					injectMessage($msg);
				}
			}
		}
	}
}

# Keep track of when we last cast a skill
sub setSkillUseTimer {
	my ($skillID, $targetID, $wait) = @_;
	my $skill = new Skills(id => $skillID);
	my $handle = $skill->handle;

	$char->{skills}{$handle}{time_used} = time;
	delete $char->{time_cast};
	delete $char->{cast_cancelled};
	$char->{last_skill_time} = time;
	$char->{last_skill_used} = $skillID;
	$char->{last_skill_target} = $targetID;

	# increment monsterSkill maxUses counter
	if ($monsters{$targetID}) {
		$monsters{$targetID}{skillUses}{$skill->handle}++;
	}

	# Set encore skill if applicable
	$char->{encoreSkill} = $skill if $targetID eq $accountID && $skillsEncore{$skill->handle};
}

sub setPartySkillTimer {
	my ($skillID, $targetID) = @_;
	my $skill = new Skills(id => $skillID);
	my $handle = $skill->handle;

	# set partySkill target_time
	my $i = $targetTimeout{$targetID}{$handle};
	$ai_v{"partySkill_${i}_target_time"}{$targetID} = time if $i;
}


##
# setStatus(ID, param1, param2, param3)
# ID: ID of a player or monster.
# param1: the state information of the object.
# param2: the ailment information of the object.
# param3: the "look" information of the object.
#
# Sets the state, ailment, and "look" statuses of the object.
# Does not include skillsstatus.txt items.
sub setStatus {
	my ($ID, $param1, $param2, $param3) = @_;

	my $actor = Actor::get($ID);

	my $verbosity = $ID eq $accountID ? 1 : 2;
	my $are = $actor->verb('are', 'is');
	my $have = $actor->verb('have', 'has');

	foreach (keys %skillsState) {
		if ($param1 == $_) {
			if (!$actor->{statuses}{$skillsState{$_}}) {
				$actor->{statuses}{$skillsState{$_}} = 1;
				message "$actor $are in $skillsState{$_} state\n", "parseMsg_statuslook", $verbosity;
			}
		} elsif ($actor->{statuses}{$skillsState{$_}}) {
			delete $actor->{statuses}{$skillsState{$_}};
			message "$actor $are out of $skillsState{$_} state\n", "parseMsg_statuslook", $verbosity;
		}
	}

	foreach (keys %skillsAilments) {
		if (($param2 & $_) == $_) {
			if (!$actor->{statuses}{$skillsAilments{$_}}) {
				$actor->{statuses}{$skillsAilments{$_}} = 1;
				message "$actor $have ailments: $skillsAilments{$_}\n", "parseMsg_statuslook", $verbosity;
			}
		} elsif ($actor->{statuses}{$skillsAilments{$_}}) {
			delete $actor->{statuses}{$skillsAilments{$_}};
			message "$actor $are out of ailments: $skillsAilments{$_}\n", "parseMsg_statuslook", $verbosity;
		}
	}

	foreach (keys %skillsLooks) {
		if (($param3 & $_) == $_) {
			if (!$actor->{statuses}{$skillsLooks{$_}}) {
				$actor->{statuses}{$skillsLooks{$_}} = 1;
				debug "$actor $have look: $skillsLooks{$_}\n", "parseMsg_statuslook", $verbosity;
			}
		} elsif ($actor->{statuses}{$skillsLooks{$_}}) {
			delete $actor->{statuses}{$skillsLooks{$_}};
			debug "$actor $are out of look: $skillsLooks{$_}\n", "parseMsg_statuslook", $verbosity;
		}
	}
}


# Increment counter for monster being casted on
sub countCastOn {
	my ($sourceID, $targetID, $skillID, $x, $y) = @_;
	return unless defined $targetID;

	if ($monsters{$sourceID}) {
		if ($targetID eq $accountID) {
			$monsters{$sourceID}{'castOnToYou'}++;
		} elsif ($players{$targetID} && %{$players{$targetID}}) {
			$monsters{$sourceID}{'castOnToPlayer'}{$targetID}++;
		} elsif ($monsters{$targetID} && %{$monsters{$targetID}}) {
			$monsters{$sourceID}{'castOnToMonster'}{$targetID}++;
		}
	}

	if ($monsters{$targetID}) {
		if ($sourceID eq $accountID) {
			$monsters{$targetID}{'castOnByYou'}++;
		} elsif ($players{$sourceID} && %{$players{$sourceID}}) {
			$monsters{$targetID}{'castOnByPlayer'}{$sourceID}++;
		} elsif ($monsters{$sourceID} && %{$monsters{$sourceID}}) {
			$monsters{$targetID}{'castOnByMonster'}{$sourceID}++;
		}
	}
}
sub stopAttack {
	my $pos = calcPosition($char);
	sendMove($pos->{x}, $pos->{y});
}

sub stripLanguageCode {
	my $r_msg = shift;
	if ($config{chatLangCode} && $config{chatLangCode} ne "none") {
		if ($$r_msg =~ /^\|..(.*)/) {
			$$r_msg = $1;
			return 1;
		}
		return 0;
	} else {
		return 0;
	}
}

##
# switchConf(filename)
# filename: a configuration file.
# Returns: 1 on success, 0 if $filename does not exist.
#
# Switch to another configuration file.
sub switchConfigFile {
	my $filename = shift;
	if (! -f $filename) {
		error "$filename does not exist.\n";
		return 0;
	}

	foreach (@Settings::configFiles) {
		if ($_->{file} eq $Settings::config_file) {
			$_->{file} = $filename;
			last;
		}
	}
	$Settings::config_file = $filename;
	parseConfigFile($filename, \%config);
	return 1;
}

sub updateDamageTables {
	my ($ID1, $ID2, $damage) = @_;

	# Track deltaHp
	#
	# A player's "deltaHp" initially starts at 0.
	# When he takes damage, the damage is subtracted from his deltaHp.
	# When he is healed, this amount is added to the deltaHp.
	# If the deltaHp becomes positive, it is reset to 0.
	#
	# Someone with a lot of negative deltaHp is probably in need of healing.
	# This allows us to intelligently heal non-party members.
	if (my $target = Actor::get($ID2)) {
		$target->{deltaHp} -= $damage;
		$target->{deltaHp} = 0 if $target->{deltaHp} > 0;
	}

	if ($ID1 eq $accountID) {
		if ($monsters{$ID2}) {
			# You attack monster
			$monsters{$ID2}{'dmgTo'} += $damage;
			$monsters{$ID2}{'dmgFromYou'} += $damage;
			$monsters{$ID2}{'numAtkFromYou'}++;
			if ($damage <= ($config{missDamage} || 0)) {
				$monsters{$ID2}{'missedFromYou'}++;
				debug "Incremented missedFromYou count to $monsters{$ID2}{'missedFromYou'}\n", "attackMonMiss";
				$monsters{$ID2}{'atkMiss'}++;
			} else {
				$monsters{$ID2}{'atkMiss'} = 0;
			}
			 if ($config{'teleportAuto_atkMiss'} && $monsters{$ID2}{'atkMiss'} >= $config{'teleportAuto_atkMiss'}) {
				message "Teleporting because of attack miss\n", "teleport";
				useTeleport(1);
			}
			if ($config{'teleportAuto_atkCount'} && $monsters{$ID2}{'numAtkFromYou'} >= $config{'teleportAuto_atkCount'}) {
				message "Teleporting after attacking a monster $config{'teleportAuto_atkCount'} times\n", "teleport";
				useTeleport(1);
			}
		}

	} elsif ($ID2 eq $accountID) {
		if ($monsters{$ID1}) {
			# Monster attacks you
			$monsters{$ID1}{'dmgFrom'} += $damage;
			$monsters{$ID1}{'dmgToYou'} += $damage;
			if ($damage == 0) {
				$monsters{$ID1}{'missedYou'}++;
			}
			$monsters{$ID1}{'attackedYou'}++ unless (
					scalar(keys %{$monsters{$ID1}{'dmgFromPlayer'}}) ||
					scalar(keys %{$monsters{$ID1}{'dmgToPlayer'}}) ||
					$monsters{$ID1}{'missedFromPlayer'} ||
					$monsters{$ID1}{'missedToPlayer'}
				);
			$monsters{$ID1}{target} = $ID2;

			if ($AI) {
				my $teleport = 0;
				if (mon_control($monsters{$ID1}{'name'})->{'teleport_auto'} == 2){
					message "Teleporting due to attack from $monsters{$ID1}{'name'}\n", "teleport";
					$teleport = 1;
				} elsif ($config{'teleportAuto_deadly'} && $damage >= $chars[$config{'char'}]{'hp'} && !whenStatusActive("Hallucination")) {
					message "Next $damage dmg could kill you. Teleporting...\n", "teleport";
					$teleport = 1;
				} elsif ($config{'teleportAuto_maxDmg'} && $damage >= $config{'teleportAuto_maxDmg'} && !whenStatusActive("Hallucination") && !($config{'teleportAuto_maxDmgInLock'} && $field{'name'} eq $config{'lockMap'})) {
					message "$monsters{$ID1}{'name'} hit you for more than $config{'teleportAuto_maxDmg'} dmg. Teleporting...\n", "teleport";
					$teleport = 1;
				} elsif ($config{'teleportAuto_maxDmgInLock'} && $field{'name'} eq $config{'lockMap'} && $damage >= $config{'teleportAuto_maxDmgInLock'} && !whenStatusActive("Hallucination")) {
					message "$monsters{$ID1}{'name'} hit you for more than $config{'teleportAuto_maxDmgInLock'} dmg in lockMap. Teleporting...\n", "teleport";
					$teleport = 1;
				} elsif (AI::inQueue("sitAuto") && $config{'teleportAuto_attackedWhenSitting'} && $damage > 0) {
					message "$monsters{$ID1}{'name'} attacks you while you are sitting. Teleporting...\n", "teleport";
					$teleport = 1;
				} elsif ($config{'teleportAuto_totalDmg'} && $monsters{$ID1}{'dmgToYou'} >= $config{'teleportAuto_totalDmg'} && !whenStatusActive("Hallucination") && !($config{'teleportAuto_totalDmgInLock'} && $field{'name'} eq $config{'lockMap'})) {
					message "$monsters{$ID1}{'name'} hit you for a total of more than $config{'teleportAuto_totalDmg'} dmg. Teleporting...\n", "teleport";
					$teleport = 1;
				} elsif ($config{'teleportAuto_totalDmgInLock'} && $field{'name'} eq $config{'lockMap'} && $monsters{$ID1}{'dmgToYou'} >= $config{'teleportAuto_totalDmgInLock'} && !whenStatusActive("Hallucination")) {
					message "$monsters{$ID1}{'name'} hit you for a total of more than $config{'teleportAuto_totalDmgInLock'} dmg in lockMap. Teleporting...\n", "teleport";
					$teleport = 1;
				}
				useTeleport(1) if ($teleport);
			}
		}

	} elsif ($monsters{$ID1}) {
		if ($players{$ID2}) {
			# Monster attacks player
			$monsters{$ID1}{'dmgFrom'} += $damage;
			$monsters{$ID1}{'dmgToPlayer'}{$ID2} += $damage;
			$players{$ID2}{'dmgFromMonster'}{$ID1} += $damage;
			if ($damage == 0) {
				$monsters{$ID1}{'missedToPlayer'}{$ID2}++;
				$players{$ID2}{'missedFromMonster'}{$ID1}++;
			}
			if (existsInList($config{tankersList}, $players{$ID2}{name}) ||
			    ($chars[$config{'char'}]{'party'} && %{$chars[$config{'char'}]{'party'}} && $chars[$config{'char'}]{'party'}{'users'}{$ID2} && %{$chars[$config{'char'}]{'party'}{'users'}{$ID2}})) {
				# Monster attacks party member
				$monsters{$ID1}{'dmgToParty'} += $damage;
				$monsters{$ID1}{'missedToParty'}++ if ($damage == 0);
			}
			$monsters{$ID1}{target} = $ID2;
		}

	} elsif ($players{$ID1}) {
		if ($monsters{$ID2}) {
			# Player attacks monster
			$monsters{$ID2}{'dmgTo'} += $damage;
			$monsters{$ID2}{'dmgFromPlayer'}{$ID1} += $damage;
			$monsters{$ID2}{'lastAttackFrom'} = $ID1;
			$players{$ID1}{'dmgToMonster'}{$ID2} += $damage;

			if ($damage == 0) {
				$monsters{$ID2}{'missedFromPlayer'}{$ID1}++;
				$players{$ID1}{'missedToMonster'}{$ID2}++;
			}

			if (existsInList($config{tankersList}, $players{$ID1}{name}) ||
			    ($chars[$config{'char'}]{'party'} && %{$chars[$config{'char'}]{'party'}} && $chars[$config{'char'}]{'party'}{'users'}{$ID1} && %{$chars[$config{'char'}]{'party'}{'users'}{$ID1}})) {
				$monsters{$ID2}{'dmgFromParty'} += $damage;
			}
		}
	}
}

##
# useTeleport(level)
# level: 1 to teleport to a random spot, 2 to respawn.
sub useTeleport {
	my $use_lvl = shift;
	my $internal = shift;

	# for possible recursive calls
	if (!defined $internal) {
		$internal = $config{teleportAuto_useSkill};
	}

	# look if the character has the skill
	my $sk_lvl = 0;
	if ($char->{skills}{AL_TELEPORT}) {
		$sk_lvl = $char->{skills}{AL_TELEPORT}{lv};
	}

	# only if we want to use skill ?
	return if ($char->{muted});

	if ($sk_lvl > 0 && $internal > 0) {
		# We have the teleport skill, and should use it
		my $skill = new Skills(handle => 'AL_TELEPORT');
		if ($internal == 1 || ($internal == 2 && binSize(\@playersID))) {
			# Send skill use packet to appear legitimate
			sendSkillUse(\$remote_socket, $skill->id, $use_lvl, $accountID);
			undef $char->{permitSkill};
		}

		delete $ai_v{temp}{teleport};
		debug "Sending Teleport using Level $use_lvl\n", "useTeleport";
		if ($use_lvl == 1) {
			sendTeleport(\$remote_socket, "Random");
			return 1;
		} elsif ($use_lvl == 2) {
			# check for possible skill level abuse
			message "Using Teleport Skill Level 2 though we not have it !\n", "useTeleport" if ($sk_lvl == 1);

			# If saveMap is not set simply use a wrong .gat.
			# eAthena servers ignore it, but this trick doesn't work
			# on official servers.
			my $telemap = "prontera.gat";
			$telemap = "$config{saveMap}.gat" if ($config{saveMap} ne "");

			sendTeleport(\$remote_socket, $telemap);
			return 1;
		}
	}

	# else if $internal == 0 or $sk_lvl == 0
	# try to use item

	# could lead to problems if the ItemID would be different on some servers
	my $invIndex = findIndex($char->{inventory}, "nameID", $use_lvl + 600);
	if (defined $invIndex) {
		# We have Fly Wing/Butterfly Wing.
		# Don't spam the "use fly wing" packet, or we'll end up using too many wings.
		if (timeOut($timeout{ai_teleport})) {
			sendItemUse(\$remote_socket, $char->{inventory}[$invIndex]{index}, $accountID);
			$timeout{ai_teleport}{time} = time;
		}
		return 1;
	}

	# no item, but skill is still available
	if ( $sk_lvl > 0 ) {
		message "No Fly Wing or Butterfly Wing, fallback to Teleport Skill\n", "useTeleport";
		return useTeleport($use_lvl, 1);
	}

	# No skill and no wings; try to equip a Tele clip or something,
	# if equipAuto_#_onTeleport is set
	my $i = 0;
	while (exists $config{"equipAuto_$i"}) {
		if (!$config{"equipAuto_$i"}) {
			$i++;
			next;
		}

		if ($config{"equipAuto_${i}_onTeleport"}) {
			# it is safe to always set this value, because $ai_v{temp} is always cleared after teleport
			if (!$ai_v{temp}{teleport}{lv}) {
				debug "Equipping " . $config{"equipAuto_$i"} . " to teleport\n", "useTeleport";
				$ai_v{temp}{teleport}{lv} = $use_lvl;

				# set a small timeout, will be overridden if related config in equipAuto is set
				$ai_v{temp}{teleport}{ai_equipAuto_skilluse_giveup}{time} = time;
				$ai_v{temp}{teleport}{ai_equipAuto_skilluse_giveup}{timeout} = 5;
				return 1;

			} elsif (defined $ai_v{temp}{teleport}{ai_equipAuto_skilluse_giveup} && timeOut($ai_v{temp}{teleport}{ai_equipAuto_skilluse_giveup})) {
				message "You don't have wing or skill to teleport/respawn or timeout elapsed\n", "teleport";
				delete $ai_v{temp}{teleport};
				return 0;

			} else {
				# Waiting for item to equip
				return 1;
			}
		}
		$i++;
	}

	if ($use_lvl == 1) {
		message "You don't have the Teleport skill or a Fly Wing\n", "teleport";
	} else {
		message "You don't have the Teleport skill or a Butterfly Wing\n", "teleport";
	}

	return 0;
}


##
# whenGroundStatus(target, statuses)
# target: coordinates hash
# statuses: a comma-separated list of ground effects e.g. Safety Wall,Pneuma
#
# Returns 1 if $target has one of the ground effects specified by $statuses.
sub whenGroundStatus {
	my ($pos, $statuses) = @_;

	my ($x, $y) = ($pos->{x}, $pos->{y});
	for my $ID (@spellsID) {
		my $spell;
		next unless ($spell = $spells{$ID});
		if ($x == $spell->{pos}{x} &&
		    $y == $spell->{pos}{y}) {
			return 1 if existsInList($statuses, getSpellName($spell->{type}));
		}
	}
	return 0;
}

sub whenStatusActive {
	my $statuses = shift;
	my @arr = split /,/, $statuses;
	foreach (@arr) {
		s/^\s+//g;
		s/\s+$//g;
		return 1 if exists($char->{statuses}{$_});
	}
	return 0;
}

sub whenStatusActiveMon {
	my ($monster, $statuses) = @_;
	my @arr = split /,/, $statuses;
	foreach (@arr) {
		s/^\s+//g;
		s/\s+$//g;
		return 1 if $monster->{statuses}{$_};
	}
	return 0;
}

sub whenStatusActivePL {
	my ($ID, $statuses) = @_;
	if ($ID eq $accountID) { return whenStatusActive($statuses) }
	my @arr = split /,/, $statuses;
	foreach (@arr) {
		s/^\s+//g;
		s/\s+$//g;
		return 1 if $players{$ID}{statuses}{$_};
	}
	return 0;
}

sub writeStorageLog {
	my ($show_error_on_fail) = @_;
	my $f;

	if (open($f, "> $Settings::storage_file")) {
		print $f "---------- Storage ". getFormattedDate(int(time)) ." -----------\n";
		for (my $i = 0; $i < @storageID; $i++) {
			next if (!$storageID[$i]);
			my $item = $storage{$storageID[$i]};

			my $display = sprintf "%2d %s x %s", $i, $item->{name}, $item->{amount};
			$display .= " -- Not Identified" if !$item->{identified};
			$display .= " -- Broken" if $item->{broken};
			print $f "$display\n";
		}
		print $f "\nCapacity: $storage{items}/$storage{items_max}\n";
		print $f "-------------------------------\n";
		close $f;

	} elsif ($show_error_on_fail) {
		error "Unable to write to $Settings::storage_file\n";
	}
}


OpenKoreMod::initMisc() if defined(&OpenKoreMod::initMisc);

return 1;
