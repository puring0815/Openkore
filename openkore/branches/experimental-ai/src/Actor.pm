#########################################################################
#  OpenKore - Base class for all actor objects
#  Copyright (c) 2005 OpenKore Team
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
# MODULE DESCRIPTION: Base class for all actor objects
#
# The Actor class is a base class for all actor objects.
# An actor object is a monster or player (all members of %monsters and
# %players). Do not create an object of this class; use one of the
# subclasses instead.
#
# An actor object is also a hash.
#
# Child classes: @MODULE(Actor::Monster), @MODULE(Actor::Player) and @MODULE(Actor::You)

package Actor;
use strict;
use Globals;
use Utils;
use Log qw(message error debug);
use Misc;

# Make it so that
#     print $actor;
# acts the same as
#     print $actor->nameString;
use overload '""' => \&_nameString;
use overload 'eq' => \&_eq;
use overload 'ne' => \&_ne;

sub _eq {
	my ($self, $other) = @_;
	return $self->{ID} eq $other->{ID};
}

sub _ne {
	my ($self, $other) = @_;
	return $self->{ID} ne $other->{ID};
}

# This function is needed to make the operator overload respect inheritance.
sub _nameString {
	my $self = shift;

	$self->nameString(@_);
}

### CATEGORY: Class methods

##
# Actor Actor::get(ID)
#
# Returns the actor object for $ID.
sub get {
	my ($ID) = @_;

	if ($ID eq $accountID) {
		return $char;
	} elsif ($players{$ID}) {
		return $players{$ID} if UNIVERSAL::isa($players{$ID}, "Actor");
		return new Actor::Unknown($ID);
	} elsif ($monsters{$ID}) {
		return $monsters{$ID} if UNIVERSAL::isa($monsters{$ID}, "Actor");
		return new Actor::Unknown($ID);
	} elsif ($items{$ID}) {
		return $items{$ID};
	} else {
		return new Actor::Unknown($ID);
	}
}

### CATEGORY: Hash members

##
# String $Actor->{type}
# Invariant: defined(value)
#
# The actor's type. Can be "Monster", "Player" or "You".

##
# int $Actor->{binID}
# Invariant: value > 0
#
# The index of this actor inside its associated actor list.

##
# Bytes $Actor->{ID}
# Invariant: length(value) == 4
#
# The server's internal unique ID for this actor (the actor's account ID).

##
# int $Actor->{nameID}
# Invariant: value > 0
#
# $Actor->{ID} decoded into an 32-bit little endian integer.

##
# int $Actor->{appear_time}
# Invariant: value > 0
#
# The time when this actor first appeared on screen.


### CATEGORY: Methods

##
# String $Actor->nameString([Actor otherActor])
#
# Returns the name string of an actor, e.g. "Player pmak (3)",
# "Monster Poring (0)" or "You".
#
# If $otherActor is specified and is equal to $actor, then it will
# return 'self' or 'yourself' instead.
sub nameString {
	my ($self, $otherActor) = @_;

	return $self->selfString if $self->{ID} eq $otherActor->{ID};

	my $nameString = "$self->{type} ".$self->name;
	$nameString .= " ($self->{binID})" if defined $self->{binID};
	return $nameString;
}

##
# String $Actor->selfString()
#
# Returns 'itself' for monsters, or 'himself/herself' for players.
# ('yourself' is handled by Actor::You.nameString.)
sub selfString {
	return 'itself';
}

##
# String $Actor->name()
#
# Returns the name of an actor, e.g. "pmak" or "Unknown #300001".
sub name {
	my ($self) = @_;

	return $self->{name} || "Unknown #".unpack("V1", $self->{ID});
}

##
# String $Actor->nameIdx()
#
# Returns the name and index of an actor, e.g. "pmak (0)" or "Unknown #300001 (1)".
sub nameIdx {
	my ($self) = @_;

	my $nameIdx = $self->name;
	$nameIdx .= " ($self->{binID})" if defined $self->{binID};
	return $nameIdx;

#	return $self->{name} || "Unknown #".unpack("V1", $self->{ID});
}

##
# String $Actor->verb(Actor you, Actor other)
#
# Returns $you if $actor is you; $other otherwise.
sub verb {
	my ($self, $you, $other) = @_;

	return $you if $self->{type} eq 'You';
	return $other;
}

##
# Hash $Actor->position()
#
# Returns the position of the actor.
sub position {
	my ($self) = @_;

	return calcPosition($self);
}

##
# float $Actor->distance([Actor otherActor])
#
# Returns the distance to another actor (defaults to yourself).
sub distance {
	my ($self, $otherActor) = @_;

	$otherActor ||= $char;
	return Utils::distance($self->position, $otherActor->position);
}

##
# float $Actor->blockDistance([Actor otherActor])
#
# Returns the block distance to another actor (defaults to yourself).
sub blockDistance {
	my ($self, $otherActor) = @_;

	$otherActor ||= $char;
	return Utils::blockDistance($self->position, $otherActor->position);
}

##
# boolean $Actor->snipable()
#
# Returns whether or not you have snipable LOS to the actor.
sub snipable {
	my ($self) = @_;

	return checkLineSnipable($char->position, $self->position);
}

1;
