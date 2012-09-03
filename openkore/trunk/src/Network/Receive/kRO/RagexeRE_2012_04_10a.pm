#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http:#//www.gnu.org/licenses/gpl.html for the full license.
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::kRO::RagexeRE_2012_04_10a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2012_03_07f);

# TODO
# 0x08E6,4
# 0x08E8,-1
# 0x08EA,4
# 0x08EC,73
# 0x08ED,43
# 0x08EE,6
# 0x08F0,6
# 0x08F2,36
# 0x08F3,-1
# 0x08F4,6
# 0x08F6,22
# 0x08F7,3
# 0x08F8,7
# 0x08F9,6
# 0x08FA,6
# 0x0908,5

1;
