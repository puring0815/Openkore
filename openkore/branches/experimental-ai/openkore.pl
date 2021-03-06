#!/usr/bin/env perl
#########################################################################
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#########################################################################

use FindBin qw($RealBin);
use lib "$RealBin";
use lib "$RealBin/src";
use strict;

srand;


sub __start {

BEGIN {
	##### CHECK FOR THE XSTOOL LIBRARY #####

	if ($^O eq 'MSWin32') {
		eval "use XSTools;";
		if ($@) {
			print "$@\n";
			print STDERR "Error: XSTools.dll is not found. Please check your installation.\n";
			<STDIN>;
			exit 1;
		}

	} else {
		# We're on Unix
		my $libName = ($^O eq 'darwin') ? 'XSTools.bundle' : 'XSTools.so';
		my $libFound = 0;
		foreach (@INC) {
			if (-f "$_/$libName" || -f "$_/auto/XSTools/$libName") {
				$libFound = 1;
				last;
			}
		}
		if (!$libFound) {
			# Attempt to compile XSTools.so if it isn't available
			my $ret = system('python', "$RealBin/scons.py");
			if ($ret != 0) {
				if (($ret & 127) == 2) {
					# Ctrl+C pressed
					exit 1;
				} else {
					print STDERR "Unable to compile $libName. Please report this error at our forums.\n";
					exit 1;
				}
			}
		}
	}
}


##### SETUP WARNING AND ERROR HANDLER #####

$SIG{__DIE__} = sub {
	return unless (defined $^S && $^S == 0);

	# Determine what function to use to print the error
	my $err;
	if (!$Globals::interface || UNIVERSAL::isa($Globals::interface, "Interface::Startup")) {
		$err = sub { print TF("%s\nPress ENTER to exit this program.\n", $_[0]); <STDIN>; }
	} else {
		$err = sub { $Globals::interface->errorDialog($_[0]); };
	}

	# Extract file and line number from the die message
	my ($file, $line) = $_[0] =~ / at (.+?) line (\d+)\.$/;

	# Get rid of the annoying "@INC contains:"
	my $dieMsg = $_[0];
	$dieMsg =~ s/ \(\@INC contains: .*\)//;

	# Create error message and display it
	my $msg = TF("Program terminated unexpectedly. Error message:\n" .
		"%s\nA more detailed error report is saved to errors.txt", $dieMsg);

	my $log = '';
	$log .= "\@ai_seq = @Globals::ai_seq\n\n" if (defined @Globals::ai_seq);
	if (defined &Carp::longmess) {
		$log .= Carp::longmess(@_);
	} else {
		$log .= $dieMsg;
	}
	# Find out which line died
	if (-f $file && open(F, "< $file")) {
		my @lines = <F>;
		close F;

		my $msg;
		$msg = "$Settings::NAME version $Settings::VERSION\n\n" if (defined $Settings::VERSION);
		$msg .=  "  $lines[$line-2]" if ($line - 2 >= 0);
		$msg .= "* $lines[$line-1]";
		$msg .= "  $lines[$line]" if (@lines > $line);
		$msg .= "\n" unless $msg =~ /\n$/s;
		$log .= TF("\n\nDied at this line:\n%s\n", $msg);
	}

	if (open(F, "> errors.txt")) {
		print F $log;
		close F;
	}
	$err->($msg);
	exit 9;
};


#### INITIALIZE STARTUP INTERFACE ####

use Time::HiRes qw(time usleep);
use Getopt::Long;
use IO::Socket;
use Digest::MD5;
use Carp;


##### PARSE ARGUMENTS, FURTHER INITIALIZE INTERFACE & LOAD PLUGINS #####

use Translation;
use Settings qw(%sys);

eval "use OpenKoreMod;";
undef $@;
my $parseArgResult = Settings::parseArguments();
Settings::parseSysConfig();
Translation::initDefault(undef, $sys{locale});

use Globals;
use Interface;
$interface = Interface->switchInterface($Settings::default_interface, 1);

if ($parseArgResult eq '2') {
	$interface->displayUsage($Settings::usageText);
	exit 1;

} elsif ($parseArgResult ne '1') {
	$interface->errorDialog($parseArgResult);
	exit 1;
}

# If Misc.pm is in the same folder as openkore.pl, then the
# user is still using the old (pre-CVS cleanup) source tree.
# So bail out to prevent weird errors.
if (-f "$RealBin/Misc.pm") {
	$interface->errorDialog(T("You have old files in the OpenKore folder, which may cause conflicts.\n" .
		"Please delete your entire OpenKore source folder, and redownload everything."));
	exit 1;
}


# Use 'require' here because XSTools.so might not be compiled yet at startup
require XSTools;
if (!defined &XSTools::majorVersion) {
	$interface->errorDialog(TF("Your version of the XSTools library is too old.\n" .
		"Please read %s", "http://openkore.sourceforge.net/problems/XSTools.php"));
	exit 1;
} elsif (XSTools::majorVersion() != 3) {
	$interface->errorDialog(TF("Your version of XSTools library is incompatible.\n" .
		"Please read %s", "http://openkore.sourceforge.net/problems/XSTools.php"));
	exit 1;
} elsif (XSTools::minorVersion() < 3) {
	$interface->errorDialog(TF("Your version of the XSTools library is too old. Please upgrade it.\n" .
		"Please read %s", "http://openkore.sourceforge.net/problems/XSTools.php"));
	exit 1;
}
require PathFinding;
require WinUtils if ($^O eq 'MSWin32');

require 'functions.pl';
use Modules;
use Log;
use Utils;
use Plugins;
use FileParsers;
use Network::Receive;
use Network::Send;
use Commands;
use Misc;
use AI;
use Skills;
use Actor;
use Actor::Player;
use Actor::Monster;
use Actor::You;
use Actor::Party;
use Actor::Unknown;
use Interface;
use ChatQueue;
use Poseidon::Client;
Modules::register(qw/Globals Modules Log Utils Settings Plugins FileParsers
	Network::Receive Network::Send Commands Misc AI Skills
	Interface ChatQueue Actor Actor::Player Actor::Monster Actor::You
	Actor::Party Actor::Unknown Item Match/);

Log::message("$Settings::versionText\n");
if (!Plugins::loadAll()) {
	$interface->errorDialog(T("One or more plugins failed to load."));
	exit 1;
}
Log::message("\n");
Plugins::callHook('start');
undef $@;

##### PARSE CONFIGURATION AND DATA FILES #####

import Settings qw(addConfigFile);
addConfigFile($Settings::config_file, \%config,\&parseConfigFile);
addConfigFile($Settings::items_control_file, \%items_control,\&parseItemsControl);
addConfigFile($Settings::mon_control_file, \%mon_control, \&parseMonControl);
addConfigFile("$Settings::control_folder/overallAuth.txt", \%overallAuth, \&parseDataFile);
addConfigFile($Settings::pickupitems_file, \%pickupitems, \&parseDataFile_lc);
addConfigFile("$Settings::control_folder/responses.txt", \%responses, \&parseResponses);
addConfigFile("$Settings::control_folder/timeouts.txt", \%timeout, \&parseTimeouts);
addConfigFile($Settings::shop_file, \%shop, \&parseShopControl);
addConfigFile("$Settings::control_folder/chat_resp.txt", \@chatResponses, \&parseChatResp);
addConfigFile("$Settings::control_folder/avoid.txt", \%avoid, \&parseAvoidControl);
addConfigFile("$Settings::control_folder/priority.txt", \%priority, \&parsePriority);
addConfigFile("$Settings::control_folder/consolecolors.txt", \%consoleColors, \&parseSectionedFile);
addConfigFile("$Settings::control_folder/routeweights.txt", \%routeWeights, \&parseDataFile);
addConfigFile("$Settings::control_folder/arrowcraft.txt", \%arrowcraft_items, \&parseDataFile_lc);

addConfigFile("$Settings::tables_folder/cities.txt", \%cities_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/commanddescriptions.txt", \%descriptions, \&parseCommandsDescription);
addConfigFile("$Settings::tables_folder/directions.txt", \%directions_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/elements.txt", \%elements_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/emotions.txt", \%emotions_lut, \&parseEmotionsFile);
addConfigFile("$Settings::tables_folder/equiptypes.txt", \%equipTypes_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/haircolors.txt", \%haircolors, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/headgears.txt", \@headgears_lut, \&parseArrayFile);
addConfigFile("$Settings::tables_folder/items.txt", \%items_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/itemsdescriptions.txt", \%itemsDesc_lut, \&parseRODescLUT);
addConfigFile("$Settings::tables_folder/itemslots.txt", \%itemSlots_lut, \&parseROSlotsLUT);
addConfigFile("$Settings::tables_folder/itemslotcounttable.txt", \%itemSlotCount_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/itemtypes.txt", \%itemTypes_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/maps.txt", \%maps_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/monsters.txt", \%monsters_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/npcs.txt", \%npcs_lut, \&parseNPCs);
addConfigFile("$Settings::tables_folder/packetdescriptions.txt", \%packetDescriptions, \&parseSectionedFile);
addConfigFile("$Settings::tables_folder/portals.txt", \%portals_lut, \&parsePortals);
addConfigFile("$Settings::tables_folder/portalsLOS.txt", \%portals_los, \&parsePortalsLOS);
addConfigFile("$Settings::tables_folder/recvpackets.txt", \%rpackets, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/servers.txt", \%masterServers, \&parseSectionedFile);
addConfigFile("$Settings::tables_folder/sex.txt", \%sex_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skills.txt", \%Skills::skills, \&parseSkills);
addConfigFile("$Settings::tables_folder/spells.txt", \%spells_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skillsdescriptions.txt", \%skillsDesc_lut, \&parseRODescLUT);
addConfigFile("$Settings::tables_folder/skillssp.txt", \%skillsSP_lut, \&parseSkillsSPLUT);
addConfigFile("$Settings::tables_folder/skillsstatus.txt", \%skillsStatus, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skillsailments.txt", \%skillsAilments, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skillsstate.txt", \%skillsState, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skillslooks.txt", \%skillsLooks, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skillsarea.txt", \%skillsArea, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skillsencore.txt", \%skillsEncore, \&parseList);

Plugins::callHook('start2');
if (!Settings::load()) {
	$interface->errorDialog('A configuration file failed to load. Did you download the latest configuration files?');
	exit 1;
}
Plugins::callHook('start3');


if ($config{'adminPassword'} eq 'x' x 10) {
	Log::message(T("\nAuto-generating Admin Password due to default...\n"));
	configModify("adminPassword", vocalString(8));
#} elsif ($config{'adminPassword'} eq '') {
#	# This is where we protect the stupid from having a blank admin password
#	Log::message(T("\nAuto-generating Admin Password due to blank...\n"));
#	configModify("adminPassword", vocalString(8));
} elsif ($config{'secureAdminPassword'} eq '1') {
	# This is where we induldge the paranoid and let them have session generated admin passwords
	Log::message(T("\nGenerating session Admin Password...\n"));
	configModify("adminPassword", vocalString(8));
}

Log::message("\n");


##### INITIALIZE X-KORE ######

our $XKore_dontRedirect = 0;
my $XKore_version = $config{XKore}? $config{XKore} : $sys{XKore};
if ($XKore_version eq "1" || $XKore_version eq "inject") {
	# Inject DLL to running Ragnarok process
	require XKore;
	Modules::register("XKore");
	$net = new XKore;
	Log::warning TF("If you are having problems with XKore 1 because of GameGuard,\n" .
		"try changing the config to 'XKore proxy' (without quotes)\n" .
		"Read more about it on %s.\n", "[to be defined]") if ($config{gameGuard} == 2);
} elsif ($XKore_version eq "2") {
	# Run as a proxy bot, allowing Ragnarok to connect while botting
	require XKore2;
	Modules::register("XKore2");
	$net = new XKore2;
} elsif ($XKore_version eq "3" || $XKore_version eq "proxy") {
	# Proxy Ragnarok client connection
	require XKoreProxy;
	Modules::register("XKoreProxy");
	$net = new XKoreProxy;
} else {
	# Run as a standalone bot, with no interface to the official RO client
	require Network;
	Modules::register("Network");
	$net = new Network;
}
if (!$net) {
	# Problem with networking
	$interface->errorDialog($@);
	exit 1;
}

if ($sys{ipc}) {
	require IPC;
	require IPC::Processors;
	Modules::register("IPC", "IPC::Processors");

	my $host = $sys{ipc_manager_host};
	my $port = $sys{ipc_manager_port};
	$host = undef if ($host eq '');
	$port = undef if ($port eq '');
	$ipc = new IPC(undef, $host, $port, 1,
		       $sys{ipc_manager_bind}, $sys{ipc_manager_startAtPort});
	if (!$ipc && $@) {
		Log::error(TF("Unable to initialize the IPC subsystem: %s\n", $@));
		undef $@;
	}

	$ipc->send("new bot", userName => $config{username});
}


### COMPILE PORTALS ###

Log::message(T("Checking for new portals... "));
if (compilePortals_check()) {
	Log::message(T("found new portals!\n"));
	my $choice = $interface->showMenu(T("Compile portals?"),
		T("New portals have been added to the portals database. " .
		"The portals database must be compiled before the new portals can be used. " .
		"Would you like to compile portals now?\n"),
		[T("Yes, compile now."), T("No, don't compile it.")]);
	if ($choice == 0) {
		Log::message(T("compiling portals") . "\n\n");
		compilePortals();
	} else {
		Log::message(T("skipping compile") . "\n\n");
	}
} else {
	Log::message(T("none found\n\n"));
}


### PROMPT USERNAME AND PASSWORD IF NECESSARY ###

if ($net->version != 1) {
	my $msg;
	if (!$config{username}) {
		$msg = $interface->askInput(T("Enter Username: "));
		if (!defined($msg)) {
			exit;
		}
		configModify('username', $msg, 1);
	}
	if (!$config{password}) {
		$msg = $interface->askPassword(T("Enter Password: "));
		if (!defined($msg)) {
			exit;
		}
		configModify('password', $msg, 1);
	}

	if ($config{'master'} eq "" || $config{'master'} =~ /^\d+$/ || !exists $masterServers{$config{'master'}}) {
		my @servers = sort { lc($a) cmp lc($b) } keys(%masterServers);
		my $choice = $interface->showMenu("Master servers",
			"Please choose a master server to connect to: ",
			\@servers);
		if ($choice == -1) {
			exit;
		} else {
			configModify('master', $servers[$choice], 1);
		}
	}

} elsif ($net->version != 1 && (!$config{'username'} || !$config{'password'})) {
	$interface->errorDialog(T("No username or password set."));
	exit 1;
}

undef $msg;
undef $msgOut;
our $KoreStartTime = time;
our $conState = 1;
our $nextConfChangeTime;
our $bExpSwitch = 2;
our $jExpSwitch = 2;
our $totalBaseExp = 0;
our $totalJobExp = 0;
our $startTime_EXP = time;

initStatVars();
initRandomRestart();
initConfChange();
Log::initLogFiles();
$timeout{'injectSync'}{'time'} = time;

Log::message("\n");


##### MAIN LOOP #####

Plugins::callHook('initialized');
XSTools::initVersion();
$interface->mainLoop();
Plugins::unloadAll();

# Shutdown everything else
undef $net;
# Translation Comment: Kore's exit message
Log::message(T("Bye!\n"));
Log::message($Settings::versionText);
}

__start() unless defined $ENV{INTERPRETER};
