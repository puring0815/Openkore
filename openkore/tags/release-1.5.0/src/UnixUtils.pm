#########################################################################
#  OpenKore - Unix-specific functions
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

# Functions in this module are implemented in auto/XSTools/unix/unix.xs
package UnixUtils;

use 5.006;
use strict;
use warnings;
use Carp;

require XSLoader;
XSLoader::load('XSTools');

require DynaLoader;
my $sym = DynaLoader::dl_find_symbol_anywhere('boot_' . __PACKAGE__);
die "Unable to find symbol boot_" . __PACKAGE__ if !$sym;
DynaLoader::dl_install_xsub(__PACKAGE__ . '::bootstrap', $sym);
UnixUtils::bootstrap();

1;

##
# UnixUtils::getTerminalSize()
# Returns: an array with 2 elements.
#
# Get the size of the active terminal.
