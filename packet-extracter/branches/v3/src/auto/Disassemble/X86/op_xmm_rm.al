# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2343 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\op_xmm_rm.al)"
sub op_xmm_rm {
  use strict;
  use warnings;
  use integer;
  my ($self, $op, $size, $proc) = @_;
  my ($mod, $xmm, $rm) = $self->split_next_byte();
  my $arg = ($mod == 3) ? xmm_reg($rm) : $self->modrm($mod, $rm, $size);
  return { op=>$op, arg=>[xmm_reg($xmm), $arg], proc=>$proc };
} # op_xmm_rm

# end of Disassemble::X86::op_xmm_rm
1;
