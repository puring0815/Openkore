#########################################################################
#  OpenKore - Packet sending
#  This module contains functions for sending packets to the server.
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
package Network::Send;

use strict;
use Time::HiRes qw(time);
use Digest::MD5;
use Exporter;
use base qw(Exporter);

use Globals qw($accountID $char $charID %config $conState $encryptVal %guild $remote_socket @chars %packetDescriptions $xkore);
use Log qw(message warning error debug);
use Utils;

our @EXPORT = qw(
	decrypt
	encrypt
	injectMessage
	injectAdminMessage
	sendToClientByInject
	sendToServerByInject
	sendSyncInject
	sendMsgToServer

	sendAddSkillPoint
	sendAddStatusPoint
	sendAlignment
	sendArrowCraft
	sendAttack
	sendAttackStop
	sendAutoSpell
	sendBanCheck
	sendBuy
	sendBuyVender
	sendCardMerge
	sendCardMergeRequest
	sendCartAdd
	sendCartGet
	sendCharCreate
	sendCharDelete
	sendCharLogin
	sendChat
	sendChatRoomBestow
	sendChatRoomChange
	sendChatRoomCreate
	sendChatRoomJoin
	sendChatRoomKick
	sendChatRoomLeave
	sendCloseShop
	sendCurrentDealCancel
	sendDeal
	sendDealAccept
	sendDealAddItem
	sendDealCancel
	sendDealFinalize
	sendDealOK
	sendDealTrade
	sendDrop
	sendEmotion
	sendEnteringVender
	sendEquip
	sendFriendAccept
	sendFriendReject
	sendFriendRequest
	sendFriendRemove
	sendForgeItem
	sendGameLogin
	sendGetPlayerInfo
	sendGetStoreList
	sendGetSellList
	sendGuildAlly
	sendGuildChat
	sendGuildInfoRequest
	sendGuildJoin
	sendGuildJoinRequest
	sendGuildMemberNameRequest
	sendGuildLeave
	sendGuildRequest
	sendIdentify
	sendIgnore
	sendIgnoreAll
	sendIgnoreListGet
	sendItemUse
	sendLook
	sendMapLoaded
	sendMapLogin
	sendMasterCodeRequest
	sendMasterLogin
	sendMasterSecureLogin
	sendMemo
	sendMove
	sendOpenShop
	sendOpenWarp
	sendPartyChat
	sendPartyJoin
	sendPartyJoinRequest
	sendPartyKick
	sendPartyLeave
	sendPartyOrganize
	sendPartyShareEXP
	sendPetCapture
	sendPetFeed
	sendPetGetInfo
	sendPetPerformance
	sendPetReturnToEgg
	sendPetUnequipItem
	sendPreLoginCode
	sendQuit
	sendRaw
	sendRespawn
	sendPrivateMsg
	sendSell
	sendSellBulk
	sendSit
	sendSkillUse
	sendSkillUseLoc
	sendStorageAdd
	sendStorageClose
	sendStorageGet
	sendStand
	sendSync
	sendTake
	sendTalk
	sendTalkCancel
	sendTalkContinue
	sendTalkResponse
	sendTalkNumber
	sendTalkText
	sendTeleport
	sendUnequip
	sendWho
	);


# use SelfLoader; 1;
# __DATA__


# TODO: move decrypt(); this doesn't belong here

##
# decrypt(r_msg, themsg)
# r_msg: a reference to a scalar.
# themsg: the message to decrypt.
#
# Decrypts the packets in $themsg and put the result in the scalar
# referenced by $r_msg.
#
# Example:
# } elsif ($switch eq "ABCD") {
# 	my $level;
# 	decrypt(\$level, substr($msg, 0, 2));
sub decrypt {
	my $r_msg = shift;
	my $themsg = shift;
	my @mask;
	my $i;
	my ($temp, $msg_temp, $len_add, $len_total, $loopin, $len, $val);
	if ($config{'encrypt'} == 1) {
		undef $$r_msg;
		undef $len_add;
		undef $msg_temp;
		for ($i = 0; $i < 13;$i++) {
			$mask[$i] = 0;
		}
		$len = unpack("S1",substr($themsg,0,2));
		$val = unpack("S1",substr($themsg,2,2));
		{
			use integer;
			$temp = ($val * $val * 1391);
		}
		$temp = ~(~($temp));
		$temp = $temp % 13;
		$mask[$temp] = 1;
		{
			use integer;
			$temp = $val * 1397;
		}
		$temp = ~(~($temp));
		$temp = $temp % 13;
		$mask[$temp] = 1;
		for($loopin = 0; ($loopin + 4) < $len; $loopin++) {
 			if (!($mask[$loopin % 13])) {
  				$msg_temp .= substr($themsg,$loopin + 4,1);
			}
		}
		if (($len - 4) % 8 != 0) {
			$len_add = 8 - (($len - 4) % 8);
		}
		$len_total = $len + $len_add;
		$$r_msg = $msg_temp.substr($themsg, $len_total, length($themsg) - $len_total);
	} elsif ($config{'encrypt'} >= 2) {
		undef $$r_msg;
		undef $len_add;
		undef $msg_temp;
		for ($i = 0; $i < 17;$i++) {
			$mask[$i] = 0;
		}
		$len = unpack("S1",substr($themsg,0,2));
		$val = unpack("S1",substr($themsg,2,2));
		{
			use integer;
			$temp = ($val * $val * 34953);
		}
		$temp = ~(~($temp));
		$temp = $temp % 17;
		$mask[$temp] = 1;
		{
			use integer;
			$temp = $val * 2341;
		}
		$temp = ~(~($temp));
		$temp = $temp % 17;
		$mask[$temp] = 1;
		for($loopin = 0; ($loopin + 4) < $len; $loopin++) {
 			if (!($mask[$loopin % 17])) {
  				$msg_temp .= substr($themsg,$loopin + 4,1);
			}
		}
		if (($len - 4) % 8 != 0) {
			$len_add = 8 - (($len - 4) % 8);
		}
		$len_total = $len + $len_add;
		$$r_msg = $msg_temp.substr($themsg, $len_total, length($themsg) - $len_total);
	} else {
		$$r_msg = $themsg;
	}
}

sub encrypt {
	my $r_msg = shift;
	my $themsg = shift;
	my @mask;
	my $newmsg;
	my ($in, $out);
	my $temp;
	my $i;

	if ($config{encrypt} == 1 && $conState >= 5) {
		$out = 0;
		for ($i = 0; $i < 13;$i++) {
			$mask[$i] = 0;
		}
		{
			use integer;
			$temp = ($encryptVal * $encryptVal * 1391);
		}
		$temp = ~(~($temp));
		$temp = $temp % 13;
		$mask[$temp] = 1;
		{
			use integer;
			$temp = $encryptVal * 1397;
		}
		$temp = ~(~($temp));
		$temp = $temp % 13;
		$mask[$temp] = 1;
		for($in = 0; $in < length($themsg); $in++) {
			if ($mask[$out % 13]) {
				$newmsg .= pack("C1", int(rand() * 255) & 0xFF);
				$out++;
			}
			$newmsg .= substr($themsg, $in, 1);
			$out++;
		}
		$out += 4;
		$newmsg = pack("S2", $out, $encryptVal) . $newmsg;
		while ((length($newmsg) - 4) % 8 != 0) {
			$newmsg .= pack("C1", (rand() * 255) & 0xFF);
		}
	} elsif ($config{encrypt} >= 2 && $conState >= 5) {
		$out = 0;
		for ($i = 0; $i < 17;$i++) {
			$mask[$i] = 0;
		}
		{
			use integer;
			$temp = ($encryptVal * $encryptVal * 34953);
		}
		$temp = ~(~($temp));
		$temp = $temp % 17;
		$mask[$temp] = 1;
		{
			use integer;
			$temp = $encryptVal * 2341;
		}
		$temp = ~(~($temp));
		$temp = $temp % 17;
		$mask[$temp] = 1;
		for($in = 0; $in < length($themsg); $in++) {
			if ($mask[$out % 17]) {
				$newmsg .= pack("C1", int(rand() * 255) & 0xFF);
				$out++;
			}
			$newmsg .= substr($themsg, $in, 1);
			$out++;
		}
		$out += 4;
		$newmsg = pack("S2", $out, $encryptVal) . $newmsg;
		while ((length($newmsg) - 4) % 8 != 0) {
			$newmsg .= pack("C1", (rand() * 255) & 0xFF);
		}
	} else {
		$newmsg = $themsg;
	}

	$$r_msg = $newmsg;
}

sub injectMessage {
	my $message = shift;
	my $name = "|";
	my $msg .= $name . " : " . $message . chr(0);
	encrypt(\$msg, $msg);
	$msg = pack("C*",0x09, 0x01) . pack("S*", length($name) + length($message) + 12) . pack("C*",0,0,0,0) . $msg;
	encrypt(\$msg, $msg);
	sendToClientByInject(\$remote_socket, $msg);
}

sub injectAdminMessage {
	my $message = shift;
	my $msg = pack("C*",0x9A, 0x00) . pack("S*", length($message)+5) . $message .chr(0);
	encrypt(\$msg, $msg);
	sendToClientByInject(\$remote_socket, $msg);
}

sub sendToClientByInject {
	my $r_socket = shift;
	my $msg = shift;
	$$r_socket->send("R".pack("S", length($msg)).$msg) if $$r_socket && $$r_socket->connected();
}

sub sendToServerByInject {
	my $r_socket = shift;
	my $msg = shift;
	$$r_socket->send("S".pack("S", length($msg)).$msg) if $$r_socket && $$r_socket->connected();
}

sub sendSyncInject {
	my $r_socket = shift;
	$$r_socket->send("K".pack("S", 0)) if $$r_socket && $$r_socket->connected();
}

sub sendMsgToServer {
	my $r_socket = shift;
	my $msg = shift;

	return if (!$$r_socket || !$$r_socket->connected());
	encrypt(\$msg, $msg);
	if ($xkore) {
		sendToServerByInject(\$remote_socket, $msg);
	} else {
		$$r_socket->send($msg) if ($$r_socket && $$r_socket->connected());
	}

	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
	if ($config{debugPacket_sent} && !existsInList($config{debugPacket_exclude}, $switch)) {
		my $label = $packetDescriptions{Send}{$switch} ?
			" - $packetDescriptions{Send}{$switch})" : '';
		if ($config{debugPacket_sent} == 1) {
			debug("Packet Switch SENT: $switch$label\n", "sendPacket", 0);
		} else {
			Misc::visualDump($msg, $switch.$label);
		}
	}
}

#######################

sub sendAddSkillPoint {
	my $r_socket = shift;
	my $skillID = shift;
	my $msg = pack("C*", 0x12, 0x01) . pack("S*", $skillID);
	sendMsgToServer($r_socket, $msg);
}

sub sendAddStatusPoint {
	my $r_socket = shift;
	my $statusID = shift;
	my $msg = pack("C*", 0xBB, 0) . pack("S*", $statusID) . pack("C*", 0x01);
	sendMsgToServer($r_socket, $msg);
}

sub sendAlignment {
	my $r_socket = shift;
	my $ID = shift;
	my $alignment = shift;
	my $msg = pack("C*", 0x49, 0x01) . $ID . pack("C*", $alignment);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Alignment: ".getHex($ID).", $alignment\n", "sendPacket", 2;
}

sub sendArrowCraft {
	my $r_socket = shift;
	my $index = shift;
	my $msg = pack("C*", 0xAE, 0x01) . pack("S*", $index);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Arrowmake: $index\n", "sendPacket", 2;
}

sub sendAttack {
	my $r_socket = shift;
	my $monID = shift;
	my $flag = shift;
	my $msg;
	if ($config{serverType} == 0) {
		$msg = pack("C*", 0x89, 0x00) . $monID . pack("C*", $flag);
		
	} elsif (($config{serverType} == 1) || ($config{serverType} == 2)) {
		$msg = pack("C*", 0x89, 0x00, 0x00, 0x00) .
		$monID .
		pack("C*", 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, $flag);
		
	} elsif ($config{serverType} == 3) {
		$msg = pack("C*", 0x90, 0x01, 0xc7, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) . 
		$monID . pack("C*", 0x00, 0x00, 0x21, 0x00, 0x00, 0x00, $flag);

	} elsif ($config{serverType} == 4) {
		$msg = pack("C*", 0x85, 0x00, 0x60, 0x60) . 
		$monID .
		pack("C*", 0x64, 0x64, 0x3E, 0x63, 0x67, 0x37, $flag);
	}
	sendMsgToServer($r_socket, $msg);
	debug "Sent attack: ".getHex($monID)."\n", "sendPacket", 2;
}

sub sendAttackStop {
	my $r_socket = shift;
	#my $msg = pack("C*", 0x18, 0x01);
	# Apparently this packet is wrong. The server disconnects us if we do this.
	# Sending a move command to the current position seems to be able to emulate
	# what this function is supposed to do.

	# Don't use this function, use Misc::stopAttack() instead!
	#sendMove ($char->{'pos_to'}{'x'}, $char->{'pos_to'}{'y'});
	#debug "Sent stop attack\n", "sendPacket";
}

sub sendAutoSpell {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0xce, 0x01, $ID, 0x00, 0x00, 0x00);
	sendMsgToServer($r_socket, $msg);
}

sub sendBanCheck {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0x87, 0x01) . $ID;
	sendMsgToServer($r_socket, $msg);
	debug "Sent Account Ban Check Request : " . getHex($ID) . "\n", "sendPacket", 2; 
}

sub sendBuy {
	my $r_socket = shift;
	my $ID = shift;
	my $amount = shift;
	my $msg = pack("C*", 0xC8, 0x00, 0x08, 0x00) . pack("S*", $amount, $ID);
	sendMsgToServer($r_socket, $msg);
	debug "Sent buy: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendBuyVender {
	my $r_socket = shift;
	my $venderID = shift;
	my $ID = shift;
	my $amount = shift;
	my $msg = pack("C*", 0x34, 0x01, 0x0C, 0x00) . $venderID . pack("S*", $amount, $ID);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Vender Buy: ".getHex($ID)."\n", "sendPacket";
}

sub sendCardMerge {
	my $r_socket = shift;
	my $card_index = shift;
	my $item_index = shift;
	my $msg = pack("C*", 0x7C, 0x01) . pack("S*", $card_index, $item_index);
	#encrypt(\$msg, $msg);
	#sendToServerByInject($r_socket, $msg);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Card Merge: $card_index, $item_index\n", "sendPacket";
}

sub sendCardMergeRequest {
	my $r_socket = shift;
	my $card_index = shift;
	my $msg = pack("C*", 0x7A, 0x01) . pack("S*", $card_index);
	#encrypt(\$msg, $msg);
	#sendToServerByInject($r_socket, $msg);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Card Merge Request: $card_index\n", "sendPacket";
}

sub sendCartAdd {
	my $r_socket = shift;
	my $index = shift;
	my $amount = shift;
	my $msg = pack("C*", 0x26, 0x01) . pack("S*", $index) . pack("L*", $amount);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Cart Add: $index x $amount\n", "sendPacket", 2;
}

sub sendCartGet {
	my $r_socket = shift;
	my $index = shift;
	my $amount = shift;
	my $msg = pack("C*", 0x27, 0x01) . pack("S*", $index) . pack("L*", $amount);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Cart Get: $index x $amount\n", "sendPacket", 2;
}

sub sendCharCreate {
	my ($r_socket, $slot, $name,
	    $str, $agi, $vit, $int, $dex, $luk,
		$hair_style, $hair_color) = @_;
	$hair_color ||= 1;
	$hair_style ||= 0;

	my $msg = pack("C*", 0x67, 0x00) .
		pack("a24", $name) .
		pack("C*", $str, $agi, $vit, $int, $dex, $luk, $slot) .
		pack("S*", $hair_style, $hair_color);
	sendMsgToServer($r_socket, $msg);
}

sub sendCharDelete {
	my $r_socket = shift;
	my $charID = shift;
	my $email = shift;
	my $msg = pack("C*", 0x68, 0x00) .
			$charID . pack("a40", $email);
	sendMsgToServer($r_socket, $msg);
}

sub sendCharLogin {
	my $r_socket = shift;
	my $char = shift;
	my $msg = pack("C*", 0x66,0) . pack("C*",$char);
	sendMsgToServer($r_socket, $msg);
}

sub sendChat {
	my $r_socket = shift;
	my $message = shift;
	$message = "|00$message" if ($config{chatLangCode} && $config{chatLangCode} ne "none");
	my $msg;
	if ($config{serverType} == 3) {
		$msg = pack("C*", 0xf3, 0x00) .
			pack("S*", length($char->{name}) + length($message) + 8) .
			$char->{name} . " : $message" . chr(0);
	} elsif ($config{serverType} == 4) {
		$msg = pack("C*", 0x9F, 0x00) .
			pack("S*", length($char->{name}) + length($message) + 8) .
			$char->{name} . " : $message" . chr(0);
	} else {
		$msg = pack("C*", 0x8C, 0x00) .
			pack("S*", length($char->{name}) + length($message) + 8) .
			$char->{name} . " : $message" . chr(0);
	}
	sendMsgToServer($r_socket, $msg);
}

sub sendChatRoomBestow {
	my $r_socket = shift;
	my $name = shift;
	$name = substr($name, 0, 24) if (length($name) > 24);
	$name = $name . chr(0) x (24 - length($name));
	my $msg = pack("C*", 0xE0, 0x00, 0x00, 0x00, 0x00, 0x00).$name;
	sendMsgToServer($r_socket, $msg);
	debug "Sent Chat Room Bestow: $name\n", "sendPacket", 2;
}

sub sendChatRoomChange {
	my $r_socket = shift;
	my $title = shift;
	my $limit = shift;
	my $public = shift;
	my $password = shift;
	$password = substr($password, 0, 8) if (length($password) > 8);
	$password = $password . chr(0) x (8 - length($password));
	my $msg = pack("C*", 0xDE, 0x00).pack("S*", length($title) + 15, $limit).pack("C*",$public).$password.$title;
	sendMsgToServer($r_socket, $msg);
	debug "Sent Change Chat Room: $title, $limit, $public, $password\n", "sendPacket", 2;
}

sub sendChatRoomCreate {
	my $r_socket = shift;
	my $title = shift;
	my $limit = shift;
	my $public = shift;
	my $password = shift;
	$password = substr($password, 0, 8) if (length($password) > 8);
	$password = $password . chr(0) x (8 - length($password));
	my $msg = pack("C*", 0xD5, 0x00).pack("S*", length($title) + 15, $limit).pack("C*",$public).$password.$title;
	sendMsgToServer($r_socket, $msg);
	debug "Sent Create Chat Room: $title, $limit, $public, $password\n", "sendPacket", 2;
}

sub sendChatRoomJoin {
	my $r_socket = shift;
	my $ID = shift;
	my $password = shift;
	$password = substr($password, 0, 8) if (length($password) > 8);
	$password = $password . chr(0) x (8 - length($password));
	my $msg = pack("C*", 0xD9, 0x00).$ID.$password;
	sendMsgToServer($r_socket, $msg);
	debug "Sent Join Chat Room: ".getHex($ID)." $password\n", "sendPacket", 2;
}

sub sendChatRoomKick {
	my $r_socket = shift;
	my $name = shift;
	$name = substr($name, 0, 24) if (length($name) > 24);
	$name = $name . chr(0) x (24 - length($name));
	my $msg = pack("C*", 0xE2, 0x00).$name;
	sendMsgToServer($r_socket, $msg);
	debug "Sent Chat Room Kick: $name\n", "sendPacket", 2;
}

sub sendChatRoomLeave {
	my $r_socket = shift;
	my $msg = pack("C*", 0xE3, 0x00);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Leave Chat Room\n", "sendPacket", 2;
}

sub sendCloseShop {
	my $msg = pack("C*", 0x2E, 0x01);
	sendMsgToServer(\$remote_socket, $msg);
	debug "Shop Closed\n", "sendPacket", 2;
}

sub sendCurrentDealCancel {
	my $r_socket = shift;
	my $msg = pack("C*", 0xED, 0x00);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Cancel Current Deal\n", "sendPacket", 2;
}

sub sendDeal {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0xE4, 0x00) . $ID;
	sendMsgToServer($r_socket, $msg);
	debug "Sent Initiate Deal: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendDealAccept {
	my $r_socket = shift;
	my $msg = pack("C*", 0xE6, 0x00, 0x03);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Accept Deal\n", "sendPacket", 2;
}

sub sendDealAddItem {
	my $r_socket = shift;
	my $index = shift;
	my $amount = shift;
	my $msg = pack("C*", 0xE8, 0x00) . pack("S*", $index) . pack("L*",$amount);	
	sendMsgToServer($r_socket, $msg);
	debug "Sent Deal Add Item: $index, $amount\n", "sendPacket", 2;
}

sub sendDealCancel {
	my $r_socket = shift;
	my $msg = pack("C*", 0xE6, 0x00, 0x04);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Cancel Deal\n", "sendPacket", 2;
}

sub sendDealFinalize {
	my $r_socket = shift;
	my $msg = pack("C*", 0xEB, 0x00);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Deal OK\n", "sendPacket", 2;
}

sub sendDealOK {
	my $r_socket = shift;
	my $msg = pack("C*", 0xEB, 0x00);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Deal OK\n", "sendPacket", 2;
}

sub sendDealTrade {
	my $r_socket = shift;
	my $msg = pack("C*", 0xEF, 0x00);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Deal Trade\n", "sendPacket", 2;
}

sub sendDrop {
	my $r_socket = shift;
	my $index = shift;
	my $amount = shift;
	my $msg;
	if ($config{serverType} == 0) {
		$msg = pack("C*", 0xA2, 0x00) . pack("S*", $index, $amount);
		
	} elsif (($config{serverType} == 1) || ($config{serverType} == 2)) {
		$msg = pack("C*", 0xA2, 0x00) .
			pack("C*", 0xFF, 0xFF, 0x08, 0x10) .
			pack("S*", $index) .
			pack("C*", 0xD2, 0x9B) .
			pack("S*", $amount);
			
	} elsif ($config{serverType} == 3) {
		$msg = pack("C*", 0x16, 0x01) .
			pack("C*", 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00) .
			pack("C*", 0xc7, 0x00, 0x98, 0xe5, 0x12) .
			pack("S*", $index) .
			pack("C*", 0x00) .
			pack("S*", $amount);

	} elsif ($config{serverType} == 4) {
		$msg = pack("C*", 0x94, 0x00) .
			pack("C*", 0x61, 0x62, 0x34, 0x11) .
			pack("S*", $index) .
			pack("C*", 0x67, 0x64) .
			pack("S*", $amount);
	}
	sendMsgToServer($r_socket, $msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

sub sendEmotion {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0xBF, 0x00).pack("C1",$ID);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Emotion\n", "sendPacket", 2;
}

sub sendEnteringVender {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0x30, 0x01) . $ID;
	sendMsgToServer($r_socket, $msg);
	debug "Sent Entering Vender: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendEquip {
	my $r_socket = shift;
	my $index = shift;
	my $type = shift;
	my $msg = pack("C*", 0xA9, 0x00) . pack("S*", $index) .  pack("S*", $type);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Equip: $index\n" , 2;
}

sub sendFriendAccept {
	my $r_socket = shift;
	my $accountID = shift;
	my $charID = shift;
	my $msg = pack("C*", 0x08, 0x02) . $accountID . $charID . pack("C*", 0x01, 0x00, 0x00, 0x00);
	sendMsgToServer(\$remote_socket, $msg);
	debug "Sent Accept friend request\n", "sendPacket";
}

sub sendFriendReject {
	my $r_socket = shift;
	my $accountID = shift;
	my $charID = shift;
	my $msg = pack("C*", 0x08, 0x02) . $accountID . $charID . pack("C*", 0x00, 0x00, 0x00, 0x00);
	sendMsgToServer(\$remote_socket, $msg);
	debug "Sent Reject friend request\n", "sendPacket";
}

sub sendFriendRequest {
	my $r_socket = shift;
	my $name = shift;
	$name = substr($name, 0, 24) if (length($name) > 24);
	$name = $name . chr(0) x (24 - length($name));
	my $msg = pack("C*", 0x02, 0x02).$name;
	sendMsgToServer(\$remote_socket, $msg);
	debug "Sent Request to be a friend: $name\n", "sendPacket";
}

sub sendFriendRemove {
	my $r_socket = shift;
	my $accountID = shift;
	my $charID = shift;
	my $msg = pack("C*", 0x03, 0x02) . $accountID . $charID;
	sendMsgToServer(\$remote_socket, $msg);
	debug "Sent Remove a friend\n", "sendPacket";
}

sub sendForgeItem {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0x8E, 0x01) . pack("S*", $ID) . pack("C*", 0x00, 0x00, 0x00, 0x00, 0x00, 0x00);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Forge Item: $ID\n" , 2;
}

sub sendGameLogin {
	my $r_socket = shift;
	my $accountID = shift;
	my $sessionID = shift;
	my $sessionID2 = shift;
	my $sex = shift;
	my $msg = pack("C*", 0x65,0) . $accountID . $sessionID . $sessionID2 . pack("C*", 0,0,$sex);
	sendMsgToServer($r_socket, $msg);
}

sub sendGetPlayerInfo {
	my $r_socket = shift;
	my $ID = shift;
	my $msg;

	if ($config{serverType} == 0) {
		$msg = pack("C*", 0x94, 0x00) . $ID;

	} elsif (($config{serverType} == 1) || ($config{serverType} == 2)) {
		$msg = pack("C*", 0x94, 0x00) . pack("C*", 0x12, 0x00, 150, 75) . $ID;

	} elsif ($config{serverType} == 3) {
		$msg = pack("C*", 0x8c, 0x00, 0x12, 0x00) . $ID;

	} elsif ($config{serverType} == 4) {
		$msg = pack("C*", 0x9B, 0x00) . pack("C*", 0x66, 0x3C, 0x61, 0x62) . $ID;
	}
	sendMsgToServer($r_socket, $msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendGetStoreList {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0xC5, 0x00) . $ID . pack("C*",0x00);
	sendMsgToServer($r_socket, $msg);
	debug "Sent get store list: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendGetSellList {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0xC5, 0x00) . $ID . pack("C*",0x01);
	sendMsgToServer($r_socket, $msg);
	debug "Sent sell to NPC: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendGuildAlly {
	my $r_socket = shift;
	my $ID = shift;
	my $flag = shift;
	my $msg = pack("C*", 0x72, 0x01).$ID.pack("L1", $flag);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Ally Guild : ".getHex($ID).", $flag\n", "sendPacket", 2;
}

sub sendGuildChat {
	my $r_socket = shift;
	my $message = shift;
	$message = "|00$message" if ($config{'chatLangCode'} && $config{'chatLangCode'} ne "none");
	my $msg = pack("C*",0x7E, 0x01) . pack("S*",length($char->{name}) + length($message) + 8) .
	$char->{name} . " : " . $message . chr(0);
	sendMsgToServer($r_socket, $msg);
}

sub sendGuildInfoRequest {
	my $r_socket = shift;
	my $msg = pack("C*", 0x4d, 0x01);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Guild Information Request\n", "sendPacket";
}

sub sendGuildJoin {
	my $r_socket = shift;
	my $ID = shift;
	my $flag = shift;
	my $msg = pack("C*", 0x6B, 0x01).$ID.pack("L1", $flag);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Join Guild : ".getHex($ID).", $flag\n", "sendPacket";
}

sub sendGuildJoinRequest {
	my $ID = shift;
	my $msg = pack("C*", 0x68, 0x01).$ID.$accountID.$charID;
	sendMsgToServer(\$remote_socket, $msg);
	debug "Sent Request Join Guild: ".getHex($ID)."\n", "sendPacket";
}

sub sendGuildMemberNameRequest {
	my $r_socket = shift;
	my $ID = shift;
	my $msg;
	if ($config{serverType} == 3) {
		$msg = pack("C*", 0xa2, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) .
				$ID;
	} elsif ($config{serverType} == 4) {
		$msg = pack("C*", 0xA2, 0x00, 0x39, 0x33, 0x68, 0x3B, 0x68, 0x3B, 0x6E, 0x0A, 0xE4, 0x16) .
				$ID;
	} else {
		$msg = pack("C*", 0x93, 0x01) . $ID;
	}
	sendMsgToServer($r_socket, $msg);
	debug "Sent Guild Member Name Request : ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendGuildLeave {
	my ($reason) = @_;
	my $mess = pack("Z40", $reason);
	my $msg = pack("C*", 0x59, 0x01).$guild{ID}.$accountID.$charID.$mess;
	sendMsgToServer(\$remote_socket, $msg);
	debug "Sent Guild Leave: $reason (".getHex($msg).")\n", "sendPacket";
}

sub sendGuildRequest {
	my $r_socket = shift;
	my $page = shift;
	my $msg = pack("C*", 0x4f, 0x01).pack("L1", $page);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Guild Request Page : ".$page."\n", "sendPacket";
}

sub sendIdentify {
	my $r_socket = shift;
	my $index = shift;
	my $msg = pack("C*", 0x78, 0x01) . pack("S*", $index);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Identify: $index\n", "sendPacket", 2;
}

sub sendIgnore {
	my $r_socket = shift;
	my $name = shift;
	my $flag = shift;
	$name = substr($name, 0, 24) if (length($name) > 24);
	$name = $name . chr(0) x (24 - length($name));
	my $msg = pack("C*", 0xCF, 0x00).$name.pack("C*", $flag);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Ignore: $name, $flag\n", "sendPacket", 2;
}

sub sendIgnoreAll {
	my $r_socket = shift;
	my $flag = shift;
	my $msg = pack("C*", 0xD0, 0x00).pack("C*", $flag);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Ignore All: $flag\n", "sendPacket", 2;
}

sub sendIgnoreListGet {
	my $r_socket = shift;
	my $flag = shift;
	my $msg = pack("C*", 0xD3, 0x00);
	sendMsgToServer($r_socket, $msg);
	debug "Sent get Ignore List: $flag\n", "sendPacket", 2;
}

sub sendItemUse {
	my $r_socket = shift;
	my $ID = shift;
	my $targetID = shift;
	my $msg;
	if ($config{serverType} == 0) {
		$msg = pack("C*", 0xA7, 0x00).pack("S*",$ID).$targetID;

	} elsif (($config{serverType} == 1) || ($config{serverType} == 2)) {
		$msg = pack("C*", 0xA7, 0x00, 0x9A, 0x12, 0x1C).pack("S*", $ID, 0).$targetID;

	} elsif ($config{serverType} == 3) {
		$msg = pack("C*", 0x9f, 0x00, 0x12, 0x00, 0x00) .
			pack("S*", $ID) .
			pack("C*", 0x20, 0x60, 0xfb, 0x12, 0x00, 0x1c) .
			$targetID;

	} elsif ($config{serverType} == 4) {
		# I have gotten various packets here but this one works well for me
		$msg = pack("C*", 0x72, 0x00, 0x65, 0x36, 0x65).pack("S*", $ID).pack("C*", 0x64, 0x37).$targetID;
	}
	sendMsgToServer($r_socket, $msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

sub sendLook {
	my $r_socket = shift;
	my $body = shift;
	my $head = shift;
	my $msg;
	if ($config{serverType} == 0) {
		$msg = pack("C*", 0x9B, 0x00, $head, 0x00, $body);
		
	} elsif (($config{serverType} == 1) || ($config{serverType} == 2)) {
		$msg = pack("C*", 0x9B, 0x00, 0xF2, 0x04, 0xC0, 0xBD, $head,
			0x00, 0xA0, 0x71, 0x75, 0x12, 0x88, 0xC1, $body);
			
	} elsif ($config{serverType} == 3) {
		$msg = pack("C*", 0x85, 0x00, 0xff, 0xff, 0x9c, 0xfb, 0x12, 0x00, 0xc1, 0x12, 0x60, 0x00) .
				pack("C*", $head, 0x00, 0x72, 0x21, 0x3d, 0x33, 0x52, 0x00, 0x00, 0x00) .
				pack("C*", $body);

	} elsif ($config{serverType} == 4) {
		$msg = pack("C*", 0xF3, 0x00, 0x62, 0x32, 0x31, 0x33, $head,
			0x00, 0x60, 0x30, 0x33, 0x31, 0x31, 0x31, $body);
	}
	sendMsgToServer($r_socket, $msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

sub sendMapLoaded {
	my $r_socket = shift;
	my $msg = pack("C*", 0x7D,0x00);
	debug "Sending Map Loaded\n", "sendPacket";
	sendMsgToServer($r_socket, $msg);
}

sub sendMapLogin {
	my $r_socket = shift;
	my $accountID = shift;
	my $charID = shift;
	my $sessionID = shift;
	my $sex = shift;
	my $msg;

	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	if ($config{serverType} == 0) {
		$msg = pack("C*", 0x72,0) . $accountID . $charID . $sessionID . pack("L1", getTickCount()) . pack("C*",$sex);

	} elsif ($config{serverType} == 3) {
		my $key = pack("C*", 0x50, 0x92, 0x61, 0x00);

		$msg = pack("C*", 0x9b, 0, 0) .
			$accountID .
			pack("C*", 0, 0, 0, 0, 0) .
			$charID .
			pack("C*", 0x50, 0x92, 0x61, 0x00) . #not sure what this is yet (maybe $key?)
			#$key .
			pack("C*", 0xff, 0xff, 0xff) .
			$sessionID .
			pack("V", getTickCount()) .
			pack("C*", $sex);

	} elsif ($config{serverType} == 4) {
		# This is used on the RuRO private server.
		# A lot of packets are different so I gave up,
		# but I'll keep this code around in case anyone ever needs it.
		$msg = pack("C*", 0xF5, 0x00, 0xFF, 0xFF, 0xFF) .
                        $accountID .
                        pack("C*", 0xFF, 0xFF, 0xFF, 0xFF, 0xFF) .
                        $charID .
                        pack("C*", 0xFF, 0xFF) .
                        $sessionID .
                        pack("L1", getTickCount()) .
                        pack("C*", $sex);

	} else {
		# $config{serverType} == 1 || $config{serverType} == 2

		my $key;

		if ($config{serverType} == 1) {
			$key = pack("C*",0xFC,0x2B,0x8B,0x01,0x00);
			#	0xFA,0x12,0x00,0xE0,0x5D
			#	0xFA,0x12,0x00,0xD0,0x7B
		} else {
			$key = pack("C*", 0xFA, 0x12, 0, 0x50, 0x83);
		}

		$msg = pack("C*", 0x72, 0, 0, 0, 0) . $accountID .
			$key .
			$charID .
			pack("C*", 0xFF, 0xFF) .
			$sessionID .
			pack("L", getTickCount()) .
			pack("C", $sex);
	}

	sendMsgToServer($r_socket, $msg);
}

sub sendMasterCodeRequest {
	my $r_socket = shift;
	my $type = shift;
	my $code = shift;
	my $msg;

	if ($type eq 'code') {
		$msg = '';
		foreach (split(/ /, $code)) {
			$msg .= pack("C1",hex($_));
		}

	} else { # type eq 'type'
		if ($code == 1) {
			$msg = pack("C*", 0x04, 0x02, 0x7B, 0x8A, 0xA8, 0x90, 0x2F, 0xD8, 0xE8, 0x30, 0xF8, 0xA5, 0x25, 0x7A, 0x0D, 0x3B, 0xCE, 0x52);
		} elsif ($code == 2) {
			$msg = pack("C*", 0x04, 0x02, 0x27, 0x6A, 0x2C, 0xCE, 0xAF, 0x88, 0x01, 0x87, 0xCB, 0xB1, 0xFC, 0xD5, 0x90, 0xC4, 0xED, 0xD2);
		} elsif ($code == 3) {
			$msg = pack("C*", 0x04, 0x02, 0x42, 0x00, 0xB0, 0xCA, 0x10, 0x49, 0x3D, 0x89, 0x49, 0x42, 0x82, 0x57, 0xB1, 0x68, 0x5B, 0x85);
		} elsif ($code == 4) {
			$msg = pack("C*", 0x04, 0x02, 0x22, 0x37, 0xD7, 0xFC, 0x8E, 0x9B, 0x05, 0x79, 0x60, 0xAE, 0x02, 0x33, 0x6D, 0x0D, 0x82, 0xC6);
		} elsif ($code == 5) {
			$msg = pack("C*", 0x04, 0x02, 0xc7, 0x0A, 0x94, 0xC2, 0x7A, 0xCC, 0x38, 0x9A, 0x47, 0xF5, 0x54, 0x39, 0x7C, 0xA4, 0xD0, 0x39);
		}
	}
	$msg .= pack("C*", 0xDB, 0x01);
	sendMsgToServer($r_socket, $msg);
}

sub sendMasterLogin {
	my $r_socket = shift;
	my $username = shift;
	my $password = shift;
	my $master_version = shift;
	my $version = shift;
	my $msg;

	if ($config{serverType} == 4) {
		# This is used on the RuRO private server.
		# A lot of packets are different so I gave up,
		# but I'll keep this code around in case anyone ever needs it.
		$username = substr($username, 0, 23) if (length($username) > 23);
		$password = substr($password, 0, 23) if (length($password) > 23);

		my $tmp = pack("C*", 0x0D, 0xF0, 0xAD, 0xBA) x 6;
		substr($tmp, 0, length($username) + 1, $username . chr(0));
		$username = $tmp;

		$tmp = (pack("C*", 0x0D, 0xF0, 0xAD, 0xBA) x 3) .
			pack("C*", 0x00, 0xD0, 0xC2, 0xCF, 0xA2, 0xF9, 0xCA, 0xDF, 0x0E, 0xA6, 0xF1, 0x41);
		substr($tmp, 0, length($password) + 1, $password . chr(0));
		$password = $tmp;

		$msg = pack("C*", 0x64, 0x00, $version, 0, 0, 0) .
			$username . $password .
			pack("C*", $master_version);
	} else {
		$msg = pack("C*", 0x64, 0x00, $version, 0, 0, 0) .
			pack("a24", $username) .
			pack("a24", $password) .
			pack("C*", $master_version);
	}
	sendMsgToServer($r_socket, $msg);
}

sub sendMasterSecureLogin {
	my $r_socket = shift;
	my $username = shift;
	my $password = shift; 
	my $salt = shift;
	my $version = shift;
	my $master_version = shift;
	my $type =  shift;
	my $account = shift;
	my $md5 = Digest::MD5->new;
	my ($msg);

	if ($type % 2 == 1) {
		$salt = $salt . $password;
	} else {
		$salt = $password . $salt;
	}
	$md5->add($salt);
	if ($type < 3 ) {
		$msg = pack("C*", 0xDD, 0x01) . pack("L1", $version) . $username . chr(0) x (24 - length($username)) .
					 $md5->digest . pack("C*", $master_version);
	}else{
		$account = ($account>0) ? $account -1 : 0;
		$msg = pack("C*", 0xFA, 0x01) . pack("L1", $version) . $username . chr(0) x (24 - length($username)) .
					 $md5->digest . pack("C*", $master_version). pack("C1", $account);
	}
	sendMsgToServer($r_socket, $msg);
}

sub sendMemo {
	my $r_socket = shift;
	my $msg = pack("C*", 0x1D, 0x01);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Memo\n", "sendPacket", 2;
}

sub sendMove {
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg;

	if ($config{serverType} == 3) {
		$msg = pack("C*", 0xA7, 0x00, 0x60, 0x00, 0x00, 0x00) .
			# pack("C*", 0x0A, 0x01, 0x00, 0x00)
			pack("C*", 0xC7, 0x00, 0x00, 0x00) .
			getCoordString($x, $y);

	} elsif ($config{serverType} == 4) {
		$msg = pack("C*", 0x89, 0x00) . getCoordString($x, $y);

	} else {
		$msg = pack("C*", 0x85, 0x00) . getCoordString($x, $y);
	}

	sendMsgToServer(\$remote_socket, $msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendOpenShop {
	my ($title, $items) = @_;

	my $length = 0x55 + 0x08 * @{$items};
	my $msg = pack("C*", 0xB2, 0x01).
		pack("S*", $length).
		pack("a80", $title).
		pack("C*", 0x01);

	foreach my $item (@{$items}) {
		$msg .= pack("S1", $item->{index}).
			pack("S1", $item->{amount}).
			pack("L1", $item->{price});
	}

	sendMsgToServer(\$remote_socket, $msg);
}

sub sendOpenWarp {
	my ($r_socket, $map) = @_;
	my $msg = pack("C*", 0x1b, 0x01, 0x1b, 0x00) . $map .
		chr(0) x (16 - length($map));
	sendMsgToServer($r_socket, $msg);
}

sub sendPartyChat {
	my $r_socket = shift;
	my $message = shift;
	$message = "|00$message" if ($config{'chatLangCode'} && $config{'chatLangCode'} ne "none");
	my $msg = pack("C*",0x08, 0x01) . pack("S*",length($char->{name}) + length($message) + 8) . 
		$char->{name} . " : " . $message . chr(0);
	sendMsgToServer($r_socket, $msg);
}

sub sendPartyJoin {
	my $r_socket = shift;
	my $ID = shift;
	my $flag = shift;
	my $msg = pack("C*", 0xFF, 0x00).$ID.pack("L", $flag);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Join Party: ".getHex($ID).", $flag\n", "sendPacket", 2;
}

sub sendPartyJoinRequest {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0xFC, 0x00).$ID;
	sendMsgToServer($r_socket, $msg);
	debug "Sent Request Join Party: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendPartyKick {
	my $r_socket = shift;
	my $ID = shift;
	my $name = shift;
	$name = substr($name, 0, 24) if (length($name) > 24);
	$name = $name . chr(0) x (24 - length($name));
	my $msg = pack("C*", 0x03, 0x01).$ID.$name;
	sendMsgToServer($r_socket, $msg);
	debug "Sent Kick Party: ".getHex($ID).", $name\n", "sendPacket", 2;
}

sub sendPartyLeave {
	my $r_socket = shift;
	my $msg = pack("C*", 0x00, 0x01);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Leave Party\n", "sendPacket", 2;
}

sub sendPartyOrganize {
	my $r_socket = shift;
	my $name = shift;
	$name = substr($name, 0, 24) if (length($name) > 24);
	$name = $name . chr(0) x (24 - length($name));
	my $msg = pack("C*", 0xF9, 0x00).$name;
	sendMsgToServer($r_socket, $msg);
	debug "Sent Organize Party: $name\n", "sendPacket", 2;
}

sub sendPartyShareEXP {
	my $r_socket = shift;
	my $flag = shift;
	my $msg = pack("C*", 0x02, 0x01).pack("L", $flag);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Party Share: $flag\n", "sendPacket", 2;
}

sub sendPetCapture {
	my $r_socket = shift;
	my $monID = shift;
	my $msg = pack("C*", 0x9F, 0x01) . $monID . pack("C*", 0x00, 0x00);
	sendMsgToServer($r_socket, $msg);
	debug "Sent pet capture: ".getHex($monID)."\n", "sendPacket", 2;
}

sub sendPetFeed {
	my $r_socket = shift;
	my $msg = pack("C*", 0xA1, 0x01, 0x01);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Pet Feed\n", "sendPacket", 2;
}

sub sendPetGetInfo {
	my $r_socket = shift;
	my $msg = pack("C*", 0xA1, 0x01, 0x00);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Pet Get Info\n", "sendPacket", 2;
}

sub sendPetPerformance {
	my $r_socket = shift;
	my $msg = pack("C*", 0xA1, 0x01, 0x02);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Pet Performance\n", "sendPacket", 2;
}

sub sendPetReturnToEgg {
	my $r_socket = shift;
	my $msg = pack("C*", 0xA1, 0x01, 0x03);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Pet Return to Egg\n", "sendPacket", 2;
}

sub sendPetUnequipItem {
	my $r_socket = shift;
	my $msg = pack("C*", 0xA1, 0x01, 0x04);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Pet Unequip Item\n", "sendPacket", 2;
}

sub sendPreLoginCode {
	my $r_socket = shift;
	my $type = shift;
	my $msg;
	if ($type == 1) {
		$msg = pack("C*", 0x04, 0x02, 0x82, 0xD1, 0x2C, 0x91, 0x4F, 0x5A, 0xD4, 0x8F, 0xD9, 0x6F, 0xCF, 0x7E, 0xF4, 0xCC, 0x49, 0x2D);
	}
	sendMsgToServer($r_socket, $msg);
	debug "Sent pre-login packet $type\n", "sendPacket", 2;
}

sub sendQuit {
	my $r_socket = shift;
	my $msg = pack("C*", 0x8A, 0x01, 0x00, 0x00);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Quit\n", "sendPacket", 2;
}

sub sendRaw {
	my $r_socket = shift;
	my $raw = shift;
	my @raw;
	my $msg;
	@raw = split / /, $raw;
	foreach (@raw) {
		$msg .= pack("C", hex($_));
	}
	sendMsgToServer($r_socket, $msg);
	debug "Sent Raw Packet: @raw\n", "sendPacket", 2;
}

sub sendRespawn {
	my $r_socket = shift;
	my $msg = pack("C*", 0xB2, 0x00, 0x00);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Respawn\n", "sendPacket", 2;
}

sub sendPrivateMsg {
	my $r_socket = shift;
	my $user = shift;
	my $message = shift;
	$message = "|00$message" if ($config{'chatLangCode'} && $config{'chatLangCode'} ne "none");
	my $msg = pack("C*",0x96, 0x00) . pack("S*",length($message) + 29) . $user . chr(0) x (24 - length($user)) .
			$message . chr(0);
	sendMsgToServer($r_socket, $msg);
}

sub sendSell {
	my $r_socket = shift;
	my $index = shift;
	my $amount = shift;
	my $msg = pack("C*", 0xC9, 0x00, 0x08, 0x00) . pack("S*", $index, $amount);
	sendMsgToServer($r_socket, $msg);
	debug "Sent sell: $index x $amount\n", "sendPacket", 2;
}

sub sendSellBulk {
	my $r_socket = shift;
	my $r_array = shift;
	my $sellMsg = "";

	for (my $i = 0; $i < @{$r_array}; $i++) {
		$sellMsg .= pack("S*", $r_array->[$i]{index}, $r_array->[$i]{amount});
		debug "Sent bulk sell: $r_array->[$i]{index} x $r_array->[$i]{amount}\n", "d_sendPacket", 2;
	}

	my $msg = pack("C*", 0xC9, 0x00) . pack("S*", length($sellMsg) + 4) . $sellMsg;
	sendMsgToServer($r_socket, $msg);
}

sub sendSit {
	my $r_socket = shift;
	my $msg;
	if ($config{serverType} == 0) {
		$msg = pack("C*", 0x89, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02);

	} elsif (($config{serverType} == 1) || ($config{serverType} == 2)) {
		$msg = pack("C*", 0x89, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00,
			0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x02);

	} elsif ($config{serverType} == 3) {
		$msg = pack("C*", 0x90, 0x01, 0x00, 0x00, 0x00, 0x00 ,0x00 ,0x00,
  				  0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ,0x00 ,0x00,
				  0x00, 0x00, 0x00, 0x02);

	} elsif ($config{serverType} == 4) {
		# I get a few different packets from sitting
		# but it doesn't seem to matter which one we send
		$msg = pack("C*", 0x85, 0x00, 0x61, 0x32, 0x00, 0x00, 0x00 ,0x00 ,0x65,
  				  0x36, 0x37, 0x34, 0x32, 0x35, 0x02);
	}
	sendMsgToServer($r_socket, $msg);
	debug "Sitting\n", "sendPacket", 2;
}

sub sendSkillUse {
	my $r_socket = shift;
	my $ID = shift;
	my $lv = shift;
	my $targetID = shift;
	my $msg;
	if ($config{serverType} == 0) {
		$msg = pack("C*", 0x13, 0x01).pack("S*",$lv,$ID).$targetID;
		
	} elsif (($config{serverType} == 1) || ($config{serverType} == 2)) {
		$msg = pack("S*", 0x0113, 0x0000, $lv) .
			pack("L", 0) .
			pack("S*", $ID, 0) .
			pack("L*", 0, 0) . $targetID;
			
	} elsif ($config{serverType} == 3) {
		$msg = pack("C*", 0x72, 0x00, 0x83, 0x7C, 0xD8, 0xFE, 0x80, 0x7C) .
				pack("S*", $lv) .
				pack("C*", 0xFF, 0xFF, 0xCF, 0xFE, 0x80, 0x7C) .
				pack("S*", $ID) .
				pack("C*", 0x6A, 0x0F, 0x00, 0x00) .
				$targetID;

	} elsif ($config{serverType} == 4) {
		# this is another packet which has many possibilities
		# these numbers have been working well for me
		$msg = pack("C*", 0x90, 0x01, 0x64, 0x63) .
			pack("S*", $lv) .
			pack("C*", 0x62, 0x65, 0x66, 0x67) .
			pack("S*", $ID) .
			pack("C*", 0x6C, 0x6B, 0x68, 0x69, 0x3D, 0x6E, 0x3C, 0x0A, 0x95, 0xE3) .
			$targetID;
	}
	sendMsgToServer($r_socket, $msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

sub sendSkillUseLoc {
	my $r_socket = shift;
	my $ID = shift;
	my $lv = shift;
	my $x = shift;
	my $y = shift;
	my $msg;
	if ($config{serverType} == 0) {
		$msg = pack("C*", 0x16, 0x01).pack("S*",$lv,$ID,$x,$y);

	} elsif (($config{serverType} == 1) || ($config{serverType} == 2)) {
		$msg = pack("S*", 0x0116, 0x0000, 0x0000, $lv) .
			chr(0) . pack("S*", $ID) .
			pack("L*", 0, 0, 0) .
			pack("S*", $x) . chr(0) . pack("S*", $y);

	} elsif ($config{serverType} == 3) {
		$msg = pack("C*", 0x13, 0x01, 0xbe, 0x44, 0x00, 0x00, 0xa0, 0xc0, 0x00, 0x00) .
			pack("S*", $lv) .
			pack("C*", 0x00, 0x00, 0xa0, 0x40, 0x00, 0x00) .
			pack("S*", $ID) .
			pack("C*", 0x00, 0x00) .
			pack("S*", $x) .
			pack("C*", 0x00, 0x00, 0xa0, 0x40, 0xe0, 0x80, 0x09, 0xc2) .
			pack("S*", $y);
	} elsif ($config{serverType} == 4) {
		$msg = pack("C*", 0xA7, 0x00, 0x37, 0x65, 0x66, 0x60) . pack("S*", $lv) .
			pack("C*", 0x32) . pack("S*", $ID) .
			pack("C*", 0x3F, 0x6D, 0x6E, 0x68, 0x3D, 0x68, 0x6F, 0x0C, 0x0C, 0x93, 0xE5, 0x5C) .
			pack("S*", $x) . chr(0) . pack("S*", $y);
	}
	sendMsgToServer($r_socket, $msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendStorageAdd {
	my $r_socket = shift;
	my $index = shift;
	my $amount = shift;
	my $msg;
	if ($config{serverType} == 0) {
		$msg = pack("C*", 0xF3, 0x00) . pack("S*", $index) . pack("L*", $amount);
		
	} elsif (($config{serverType} == 1) || ($config{serverType} == 2)) {
		$msg = pack("C*", 0xF3, 0x00) . pack("C*", 0x12, 0x00, 0x40, 0x73) .
			pack("S", $index) .
			pack("C", 0xFF) .
			pack("L", $amount);
			
	} elsif ($config{serverType} == 3) {
		$msg = pack("C*", 0x94, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ,0x00 ,0x00) .
				pack("S*", $index) .
				pack("C*", 0x00, 0x00, 0x00, 0x00) .
				pack("L*", $amount);

	} elsif ($config{serverType} == 4) {
		$msg = pack("C*", 0x7E, 0x00) . pack("C*", 0x35, 0x34, 0x3D, 0x65) .
			pack("S", $index) .
			pack("C", 0x30) .
			pack("L", $amount);
	}
	sendMsgToServer($r_socket, $msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

sub sendStorageClose {
	my $r_socket = shift;
	my $msg;
	if ($config{serverType} == 3) {
		$msg = pack("C*", 0x93, 0x01);
	} else {
		$msg = pack("C*", 0xF7, 0x00);
	}
	
	sendMsgToServer($r_socket, $msg);
	debug "Sent Storage Done\n", "sendPacket", 2;
}

sub sendStorageGet {
	my $r_socket = shift;
	my $index = shift;
	my $amount = shift;
	my $msg;
	if ($config{serverType} == 0) {
		$msg = pack("C*", 0xF5, 0x00) . pack("S*", $index) . pack("L*", $amount);
		
	} elsif (($config{serverType} == 1) || ($config{serverType} == 2)) {
		$msg = pack("S*", 0x00F5, 0, 0, 0, 0, 0, $index, 0, 0) . pack("L*", $amount);
		
	} elsif ($config{serverType} == 3) {
		$msg = pack("C*", 0xf7, 0x00, 0x00, 0x00) .
				pack("V*", getTickCount()) .
				pack("C*", 0x00, 0x00, 0x00) .
				pack("S*", $index) .
				pack("C*", 0x00, 0x00, 0x00, 0x00) .
				pack("L*", $amount);
	} elsif ($config{serverType} == 4) {
		$msg = pack("C*", 0x93, 0x01, 0x3B, 0x3A, 0x33, 0x69, 0x3B, 0x3B, 0x3E, 0x3A, 0x0A, 0x0A) .
			pack("S*", $index) .
			pack("C*", 0x35, 0x34, 0x3D, 0x67) .
			pack("L*", $amount);
	}
	sendMsgToServer($r_socket, $msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

sub sendStand {
	my $r_socket = shift;
	my $msg;
	if ($config{serverType} == 0) {
		$msg = pack("C*", 0x89, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03);
		
	} elsif (($config{serverType} == 1) || ($config{serverType} == 2)) {
		$msg = pack("C*", 0x89, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00,
			0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x03);
			
	} elsif ($config{serverType} == 3) {
		$msg = pack("C*", 0x90, 0x01, 0x00, 0x00, 0x00, 0x00 ,0x00 ,0x00,
				  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
				  0x00, 0x00, 0x00, 0x03);

	} elsif ($config{serverType} == 4) {
		$msg = pack("C*", 0x85, 0x00, 0x61, 0x32, 0x00, 0x00, 0x00, 0x00,
			0x65, 0x36, 0x30, 0x63, 0x35, 0x3F, 0x03);
	}
	sendMsgToServer($r_socket, $msg);
	debug "Standing\n", "sendPacket", 2;
}

sub sendSync {
	my $r_socket = shift;
	my $initialSync = shift;
	my $msg;

	if ($config{serverType} == 0) {
		$msg = pack("C*", 0x7E, 0x00) . pack("L1", getTickCount());

	} elsif (($config{serverType} == 1) || ($config{serverType} == 2)) {
		$msg = pack("C*", 0x7E, 0x00);
		$msg .= pack("C*", 0x30, 0x00, 0x40) if ($initialSync);
		$msg .= pack("C*", 0x00, 0x00, 0x1F) if (!$initialSync);
		$msg .= pack("L", getTickCount());

	} elsif ($config{serverType} == 3) {
		$msg = pack("C*", 0x89, 0x00);
		$msg .= pack("C*", 0x30, 0x00, 0x40) if ($initialSync);
		$msg .= pack("C*", 0x00, 0x00, 0x1F) if (!$initialSync);
		$msg .= pack("L", getTickCount());

	} elsif ($config{serverType} == 4) {
		# this is for Freya servers like VanRO
		# this is probably not "correct" but it works for me
		$msg = pack("C*", 0x16, 0x01);
		$msg .= pack("C*", 0x61, 0x3A) if ($initialSync);
		$msg .= pack("C*", 0x61, 0x62) if (!$initialSync);
		$msg .= pack("L", getTickCount());
		$msg .= pack("C*", 0x0B);
	}

	sendMsgToServer($r_socket, $msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

sub sendTake {
	my $r_socket = shift;
	my $itemID = shift;
	my $msg;
	if ($config{serverType} == 0) {
		$msg = pack("C*", 0x9F, 0x00) . $itemID;
		
	} elsif (($config{serverType} == 1) || ($config{serverType} == 2)) {
		$msg = pack("C*", 0x9F, 0x00, 0x00, 0x00, 0x68) . $itemID;
		
	} elsif ($config{serverType} == 3) {
		$msg = pack("C*", 0xf5, 0x00, 0x00, 0x00, 0xb8) . $itemID;

	} elsif ($config{serverType} == 4) {
		$msg = pack("C*", 0x13, 0x01, 0x61, 0x60, 0x3B) . $itemID;
	}
	sendMsgToServer($r_socket, $msg);
	debug "Sent take\n", "sendPacket", 2;
}

sub sendTalk {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0x90, 0x00) . $ID . pack("C*",0x01);
	sendMsgToServer($r_socket, $msg);
	debug "Sent talk: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendTalkCancel {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0x46, 0x01) . $ID;
	sendMsgToServer($r_socket, $msg);
	debug "Sent talk cancel: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendTalkContinue {
	my $r_socket = shift;
	my $ID = shift;
	my $msg = pack("C*", 0xB9, 0x00) . $ID;
	sendMsgToServer($r_socket, $msg);
	debug "Sent talk continue: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendTalkResponse {
	my $r_socket = shift;
	my $ID = shift;
	my $response = shift;
	my $msg = pack("C*", 0xB8, 0x00) . $ID. pack("C1",$response);
	sendMsgToServer($r_socket, $msg);
	debug "Sent talk respond: ".getHex($ID).", $response\n", "sendPacket", 2;
}

sub sendTalkNumber {
	my $r_socket = shift;
	my $ID = shift;
	my $number = shift;
	my $msg = pack("C*", 0x43, 0x01) . $ID .
			pack("L1", $number);
	sendMsgToServer($r_socket, $msg);
	debug "Sent talk number: ".getHex($ID).", $number\n", "sendPacket", 2;
}

sub sendTalkText {
	my $r_socket = shift;
	my $ID = shift;
	my $input = shift;
	my $msg = pack("C*", 0xD5, 0x01) . pack("S*", length($input)+length($ID)+5) . $ID . $input . chr(0);
	sendMsgToServer($r_socket, $msg);
	warning "Sent talk text: ".getHex($ID).", $input\n", "sendPacket", 2;
}

sub sendTeleport {
	my $r_socket = shift;
	my $location = shift;
	$location = substr($location, 0, 16) if (length($location) > 16);
	$location .= chr(0) x (16 - length($location));
	my $msg = pack("C*", 0x1B, 0x01, 0x1A, 0x00) . $location;
	sendMsgToServer($r_socket, $msg);
	debug "Sent Teleport: $location\n", "sendPacket", 2;
}

sub sendUnequip {
	my $r_socket = shift;
	my $index = shift;
	my $msg = pack("C*", 0xAB, 0x00) . pack("S*", $index);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Unequip: $index\n", "sendPacket", 2;
}

sub sendWho {
	my $r_socket = shift;
	my $msg = pack("C*", 0xC1, 0x00);
	sendMsgToServer($r_socket, $msg);
	debug "Sent Who\n", "sendPacket", 2;
}

1;
