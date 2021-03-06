package WinUtils;

use 5.006;
use strict;
use warnings;
use Carp;

require XSLoader;
XSLoader::load('Tools');

require DynaLoader;
my $sym = DynaLoader::dl_find_symbol_anywhere('boot_' . __PACKAGE__);
die "Unable to find symbol boot_" . __PACKAGE__ if !$sym;
DynaLoader::dl_install_xsub(__PACKAGE__ . '::bootstrap', $sym);
WinUtils::bootstrap();

1;
