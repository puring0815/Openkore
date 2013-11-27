#############################################################################
#  OpenKore - Network subsystem												#
#  This module contains functions for sending messages to the server.		#
#																			#
#  This software is open source, licensed under the GNU General Public		#
#  License, version 2.														#
#  Basically, this means that you're allowed to modify and distribute		#
#  this software. However, if you distribute modified versions, you MUST	#
#  also distribute the source code.											#
#  See http://www.gnu.org/licenses/gpl.html for the full license.			#
#############################################################################
# bRO (Brazil)
package Network::Send::bRO;
use strict;
use base 'Network::Send::ServerType0';

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0941' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'094A' => ['character_move','a3', [qw(coords)]],
		'0367' => ['sync', 'V', [qw(time)]],
		'0898' => ['actor_look_at', 'v C', [qw(head body)]],
		'0929' => ['item_take', 'a4', [qw(ID)]],
		'089D' => ['item_drop', 'v2', [qw(index amount)]],
		'0884' => ['storage_password'],
		'0957' => ['storage_item_add', 'v V', [qw(index amount)]],
		'02C4' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'035F' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0369' => ['actor_info_request', 'a4', [qw(ID)]],
		'089E' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0863' => ['party_join_request_by_name', 'Z24', [qw(partyName)]], #f
		'023B' => ['homunculus_command', 'v C', [qw(commandType, commandID)]], #f
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;	
	
	my %handlers = qw(
		actor_action 0941
		character_move 094A
		sync 0367
		actor_look_at 0898
		item_take 0929
		item_drop 089D
		storage_password 0884
		storage_item_add 0957
		storage_item_remove 02C4
		skill_use_location 035F
		actor_info_request 0369
		map_login 089E
		party_join_request_by_name 0863
		homunculus_command 023B
		master_login 02B0
		buy_bulk_vender 0801
		party_setting 07D7
	);
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	$self->cryptKeys(1785990933, 1701607027, 747196614);
	return $self;
}

1;