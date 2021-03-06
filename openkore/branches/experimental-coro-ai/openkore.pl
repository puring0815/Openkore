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

package main;
use strict;
use Coro;
use Coro::State;
use Data::Dumper;
use FindBin qw($RealBin);
use lib "$RealBin";
use lib "$RealBin/src";
use lib "$RealBin/src/deps";

use Time::HiRes qw(time usleep);
use Carp::Assert;

sub __start {
	use ErrorHandler;
	use XSTools;
	srand();


	##### BASIC INITIALIZATION #####

	use Translation;
	use Settings qw(%sys $interface_name);
	use Utils::Exceptions;

	parseArguments();
	Settings::loadSysConfig();
	Translation::initDefault(undef, $sys{locale});

	use Globals qw($log $interface $command $AI $quit);
	use Log;
	use Interface;
	use KoreStage;
	use Commands;
	use AI;
	
	# First Init Logging
	$log = Log->new();

	# Init Interface
	$interface = Interface->loadInterface($interface_name);

	# Init All others
	KoreStage->loadStage();

	selfCheck();

	$command = Commands->new();
	$AI = AI->new();

	##### MAIN LOOP #####
	my $coro_interface = async { $interface->mainLoop(); };
	my $coro_ai = async { $AI->mainLoop(); };
 
 	foreach ($coro_interface, $coro_ai) {
 		$_->join();
 		cede;
 	}
	
	exit 1;
	# shutdown();
}

# Parse command-line arguments.
sub parseArguments {
	eval {
		if (!Settings::parseArguments()) {
			print Settings::getUsageText();
			exit 1;
		}
	};
	if (my $e = caught('IOException', 'ArgumentException')) {
		print "Error: $e\n";
		if ($e->isa('ArgumentException')) {
			print Settings::getUsageText();
		}
		exit 1;
	} elsif ($@) {
		die $@;
	}
}

# Perform some self-checks to ensure everything is OK.
# Precondition: $interface is initialized.
sub selfCheck {
	use Globals qw($interface);

	if ($^O eq 'MSWin32' && !defined(getprotobyname("tcp"))) {
		$interface->errorDialog(TF(
			"Your Windows TCP/IP stack is broken. Please read\n" .
			"  %s\n" .
			"to learn how to solve this.",
			"http://www.visualkore-bot.com/faq.php#tcp"));
		exit 1;
	}

	if (!defined &XSTools::majorVersion) {
		$interface->errorDialog(TF("Your version of the XSTools library is too old.\n" .
			"Please read %s", "http://www.openkore.com/aliases/xstools.php"));
		exit 1;
	} elsif (XSTools::majorVersion() != 4) {
		my $error;
		if (defined $ENV{INTERPRETER}) {
			$error = TF("Your version of (wx)start.exe is incompatible.\n" .
				"Please upgrade it by reading %s", "http://www.openkore.com/aliases/xstools.php");
		} else {
			$error = TF("Your version of XSTools library is incompatible.\n" .
				"Please upgrade it by reading %s", "http://www.openkore.com/aliases/xstools.php");
		}
		$interface->errorDialog($error);
		exit 1;
	} elsif (XSTools::minorVersion() < 8) {
		my $error;
		if (defined $ENV{INTERPRETER}) {
			$error = TF("Your version of (wx)start.exe is too old.\n" .
				"Please upgrade it by reading %s", "http://www.openkore.com/aliases/xstools.php")
		} else {
			$error = TF("Your version of the XSTools library is too old.\n" .
				"Please upgrade it by reading %s", "http://www.openkore.com/aliases/xstools.php")
		}
		$interface->errorDialog($error);
		exit 1;
	}
}

sub shutdown {
	Plugins::unloadAll();
	# Translation Comment: Kore's exit message
	Log::message(T("Bye!\n"));
	Log::message($Settings::versionText);

	if (DEBUG && open(F, ">:utf8", "benchmark-results.txt")) {
		print F Benchmark::results("mainLoop");
		close F;
		print "Benchmark results saved to benchmark-results.txt\n";
	}
}

# OpenKore Threads Callings

sub threadInterface {
	my $self = shift;
	$self->mainLoop();
}

if (!defined($ENV{INTERPRETER}) && !$ENV{NO_AUTOSTART}) {
	__start();
}

1;
