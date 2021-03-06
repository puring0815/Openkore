############################################################
# Poseidon query interface for OpenKore
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License 
# as published by the Free Software Foundation; either version 2 
# of the License, or (at your option) any later version.
#
# Copyright (c) 2005-2006 OpenKore Development Team
############################################################
##
# MODULE DESCRIPTION: Poseidon GameGuard query handler.
#
# Poseidon provides a simple way to respond to GameGuard queries.
package Poseidon::Client;

use strict;
use IO::Socket::INET;
use Globals qw(%config);
use Log qw(error debug);
use IPC::Messages qw(encode decode);
use Utils qw(dataWaiting);

use constant DEFAULT_POSEIDON_SERVER_PORT => 24390;
use constant POSEIDON_SUPPORT_URL => 'http://www.openkore.com/aliases/poseidon.php';

our $instance;


# Poseidon::Client Poseidon::Client->new(String host, int port)
#
# Create a new Poseidon::Client object.
sub _new {
	my ($class, $host, $port) = @_;
	my %self = (
		host => $host,
		port => $port
	);
	return bless \%self, $class;
}

# IO::Socket::INET $PoseidonClient->_connect()
#
# Connect to the poseidon server.
sub _connect {
	my ($self) = @_;
	my $socket = new IO::Socket::INET(
		PeerHost => $self->{host},
		PeerPort => $self->{port},
		Proto => 'tcp'
	);
	return $socket;
}

##
# void $PoseidonClient->query(Bytes packet)
# packet: A GameGuard query packet.
#
# Send a GameGuard query packet to the Poseidon core.
#
# When an appropriate response packet has been determined,
# it will be available through $PoseidonClient->getResult()
sub query {
	my ($self, $packet) = @_;
	my $socket = $self->_connect();
	if (!$socket) {
		error "Your Ragnarok Online server uses GameGuard. In order " .
			"to support GameGuard, you must start the Poseidon " .
			"server. Please read " . POSEIDON_SUPPORT_URL .
			" for more information.\n";
		return;
	}

	my (%args, $data);
	$args{packet} = $packet;
	$data = encode("Poseidon Query", \%args);
	$socket->send($data);
	$socket->flush();
	$self->{socket} = $socket;
	$self->{buf} = '';
}

##
# Bytes $PoseidonClient->getResult()
# Returns: the GameGuard query result, or undef if there is no result yet.
# Ensures: if defined(result): !defined($self->getResult())
#
# Get the result for the last query.
sub getResult {
	my ($self) = @_;

	if (!$self->{socket} || !$self->{socket}->connected
	 || !dataWaiting($self->{socket})) {
		return undef;
	}

	my ($buf, $ID, %args, $rest);
	$self->{socket}->recv($buf, 1024 * 32);
	if (!$buf) {
		# This shouldn't have happened.
		error "The Poseidon server closed the connection unexpectedly. Please report this bug.\n";
		$self->{socket} = undef;
		return undef;
	}

	$self->{buf} .= $buf;
	$ID = decode($self->{buf}, \%args, \$rest);
	if (!defined($ID)) {
		# We haven't gotten a full message yet.
		return undef;
	} elsif ($ID ne "Poseidon Reply") {
		error "The Poseidon server sent a wrong reply ID ($ID). Please report this bug.\n";
		$self->{socket} = undef;
		return undef;
	} else {
		$self->{socket} = undef;
		return $args{packet};
	}
}

##
# Poseidon::Client Poseidon::Client::getInstance()
#
# Get the global Poseidon::Client instance.
sub getInstance {
	if (!$instance) {
		$instance = Poseidon::Client->_new(
			$config{poseidonServer} || 'localhost',
			$config{poseidonPort} || DEFAULT_POSEIDON_SERVER_PORT);
	}
	return $instance;
}

1;
