package Macro::Script;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);

use Utils;
use Globals;
use AI;
use Macro::Data;
use Macro::Parser qw(parseCmd);
use Macro::Utilities qw(setVar getVar cmpr);
use Macro::Automacro qw(releaseAM lockAM);
use Log qw(message);
our $Changed = sprintf("%s %s %s",
  q$Date: 2006-03-06 00:11:21 +0100 (ma, 06 mrt 2006) $
  =~ /(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) ([+-]\d{4})/);
      
# constructor
sub new {
  my ($class, $name, $repeat) = @_;
  $repeat = 0 unless ($repeat && $repeat =~ /^\d+$/);
  return unless defined $macro{$name};
  my $self = {
    name => $name,
    registered => 0,
    submacro => 0,
    script => [@{$macro{$name}}],
    macro_delay => $timeout{macro_delay}{timeout},
    timeout => 0,
    time => time,
    finished => 0,
    overrideAI => 0,
    line => 0,
    label => {scanLabels($macro{$name})},
    repeat => $repeat,
    subcall => undef,
    error => undef,
    orphan => $::config{macro_orphans}
  };
  bless ($self, $class);
  return $self
}

# destructor
sub DESTROY {
  my $self = shift;
  AI::dequeue() if (AI::is('macro') && !$self->{submacro})
}

# declares current macro to be a submacro
sub regSubmacro {
  my $self = shift;
  $self->{submacro} = 1
}

# registers to AI queue
sub register {
  my $self = shift;
  AI::queue('macro') unless $self->{overrideAI};
  $self->{registered} = 1
}

# checks register status
sub registered {
  my $self = shift;
  return $self->{registered}
}

# sets and gets method for orphaned macros
sub orphan {
  my ($self, $method) = @_;
  if (defined $method) {$self->{orphan} = $method}
  else {return $self->{orphan}}
}

# sets repeat
sub setRepeat {
  my $self = shift;
  $self->{repeat} = shift
}

# for debugging purposes
sub printLabels {
  my $self = shift;
  foreach my $k (keys %{$self->{label}}) {
    $cvs->debug(sprintf("%s->%s", $k, ${$self->{label}}{$k}), $logfac{developers})
  }
}

# sets timeout for next command
sub setTimeout {
  my $self = shift;
  $self->{timeout} = shift
}

# sets macro_delay timeout for this macro
sub setMacro_delay {
  my $self = shift;
  $self->{macro_delay} = shift
}

# gets timeout for next command
sub timeout {
  my $self = shift;
  return (time => $self->{time}, timeout => $self->{timeout})
}

# sets override AI
sub setOverrideAI {
  my $self = shift;
  $self->{overrideAI} = 1
}

# gets override AI value
sub overrideAI {
  my $self = shift;
  return $self->{overrideAI}
}

# returns whether or not the macro finished
sub finished {
  my $self = shift;
  return $self->{finished}
}

# returns the name of the current macro
sub name {
  my $self = shift;
  return $self->{name}
}

# returns the current line number
sub line {
  my $self = shift;
  return $self->{line}
}

# returns the error line
sub error {
  my $self = shift;
  return $self->{error}
}

# re-sets the timer
sub ok {
  my $self = shift;
  $self->{time} = time
}

# scans the script for labels
sub scanLabels {
  my $script = shift;
  my %labels;
  for (my $line = 0; $line < @{$script}; $line++) {
    if (${$script}[$line] =~ /^:/) {
      my ($label) = ${$script}[$line] =~ /^:(.*)$/;
      $labels{$label} = $line
    }
    if (${$script}[$line] =~ /^while\s+/) {
      my ($label) = ${$script}[$line] =~ /\s+as\s+(.*)$/;
      $labels{$label} = $line
    }
    if (${$script}[$line] =~ /^end\s+/) {
      my ($label) = ${$script}[$line] =~ /^end\s+(.*)$/;
      $labels{"end ".$label} = $line
    }
  }
  return %labels
}

# processes next line
sub next {
  my $self = shift;
  if (defined $self->{subcall}) {
    my $command = $self->{subcall}->next;
    if (defined $command) {
      my %tmptime = $self->{subcall}->timeout;
      $self->{timeout} = $tmptime{timeout};
      $self->{time} = $tmptime{time};
      if ($self->{subcall}->finished) {
        undef $self->{subcall};
        $self->{line}++
      }
      return $command
    }
    $self->{error} = $self->{subcall}->{error};
    return
  }

  my $line = ${$self->{script}}[$self->{line}];
  if (!defined $line) {
    if ($self->{repeat} > 1) {
      $self->{repeat}--;
      $self->{line} = 0
    } else {
      $self->{finished} = 1
    }
    return ""
  }
  ##########################################
  # jump to label: goto label
  if ($line =~ /^goto\s/) {
    my ($tmp) = $line =~ /^goto\s+([a-zA-Z][a-zA-Z\d]*)/;
    if (exists $self->{label}->{$tmp}) {
      $self->{line} = $self->{label}->{$tmp}
    } else {
      $self->{error} = "error in ".$self->{line}.": cannot find label ".$tmp
    }
    $self->{timeout} = 0
  ##########################################
  # declare block ending: end label
  } elsif ($line =~ /^end\s/) {
    my ($tmp) = $line =~ /^end\s+(.*)/;
    if (exists $self->{label}->{$tmp}) {
      $self->{line} = $self->{label}->{$tmp}
    } else {
      $self->{error} = "error in ".$self->{line}.": cannot find block start"
    }
    $self->{timeout} = 0
  ##########################################
  # if statement: if (foo = bar) goto label?
  } elsif ($line =~ /^if\s/) {
    my ($first, $cond, $last, $then) = $line =~ /^if\s+\(\s*"?(.*?)"?\s+([<>=!]+?)\s+"?(.*?)"?\s*\)\s+(.*?)$/;
    if (!defined $first || !defined $cond || !defined $last || !defined $then || $then !~ /^(goto\s|stop)/) {
      $self->{error} = "error in ".$self->{line}.": syntax error in if statement"
    } else {
      my $pfirst = parseCmd($first); my $plast = parseCmd($last);
      unless (defined $pfirst && defined $plast) {
        $self->{error} = "error in ".$self->{line}.": either '$first' or '$last' has failed"
      } elsif (cmpr($pfirst, $cond, $plast)) {
        if ($then =~ /^goto\s/) {
          my ($tmp) = $then =~ /^goto\s+([a-zA-Z][a-zA-Z\d]*)$/;
          if (exists $self->{label}->{$tmp}) {
            $self->{line} = $self->{label}->{$tmp}
          } else {
            $self->{error} = "error in ".$self->{line}.": cannot find label ".$tmp
          }
        } elsif ($then =~ /^stop$/) {
          $self->{finished} = 1
        }
      } else {
        $self->{line}++
      }
    }
    $self->{timeout} = 0
  ##########################################
  # while statement: while (foo <= bar) as label
  } elsif ($line =~ /^while\s/) {
    my ($first, $cond, $last, $label) = $line =~ /^while\s+\(\s*"?(.*?)"?\s+([<>=!]+?)\s+"?(.*?)"?\s*\)\s+as\s+(.*)$/;
    if (!defined $first || !defined $cond || !defined $last || !defined $label) {
      $self->{error} = "error in ".$self->{line}.": syntax error in while statement"
    } else {
      my $pfirst = parseCmd($first); my $plast = parseCmd($last);
      unless (defined $pfirst && defined $plast) {
        $self->{error} = "error in ".$self->{line}.": either '$first' or '$last' has failed"
      } elsif (!cmpr($pfirst, $cond, $plast)) {
        $self->{line} = $self->{label}->{"end ".$label}
      }
      $self->{line}++
    }
    $self->{timeout} = 0
  ##########################################
  # set variable: $variable = value
  } elsif ($line =~ /^\$[a-z]/i) {
    my ($var, $val);
    if (($var, $val) = $line =~ /^\$([a-z][a-z\d]*?)\s+=\s+(.*)$/i) {
      my $pval = parseCmd($val);
      if (defined $pval) {setVar($var, $pval)}
      else {$self->{error} = "error in ".$self->{line}.": $val failed"}
    } elsif (($var, $val) = $line =~ /^\$([a-z][a-z\d]*?)([+-]{2})$/i) {
      if ($val eq '++') {setVar($var, (getVar($var) or 0)+1)}
      else {setVar($var, (getVar($var) or 0)-1)}
    } else {
      $self->{error} = "error in ".$self->{line}.": unrecognized assignment"
    }
    $self->{line}++;
    $self->{timeout} = $self->{macro_delay}
  ##########################################
  # set doublevar: ${$variable} = value
  } elsif ($line =~ /^\$\{\$[.a-z]/i) {
    my ($dvar, $val);
    if (($dvar, $val) = $line =~ /^\$\{\$([.a-z][a-z\d]*?)\}\s+=\s+(.*)$/i) {
      my $var = getVar($dvar);
      unless (defined $var) {
        $self->{error} = "error in ".$self->{line}.": $dvar not defined"
      } else {
        my $pval = parseCmd($val);
        unless (defined $pval) {
          $self->{error} = "error in ".$self->{line}.": $val failed"
        } else {
          setVar("#".$var, parseCmd($val))
        }
      }
    } elsif (($dvar, $val) = $line =~ /^\$\{\$([.a-z][a-z\d]*?)\}([+-]{2})$/i) {
      my $var = getVar($dvar);
      unless (defined $var) {
        $self->{error} = "error in ".$self->{line}.": $dvar undefined"
      } else {
        if ($val eq '++') {setVar("#".$var, (getVar("#".$var) or 0)+1)}
        else {setVar("#".$var, (getVar("#".$var) or 0)-1)}
      }
    } else {
        $self->{error} = "error in ".$self->{line}.": unrecognized assignment."
    }
    $self->{line}++;
    $self->{timeout} = $self->{macro_delay}
  ##########################################
  # label definition: :label
  } elsif ($line =~ /^:/) {
    $self->{line}++;
    $self->{timeout} = 0
  ##########################################
  # returns command: do whatever
  } elsif ($line =~ /^do\s/) {
    my ($tmp) = $line =~ /^do\s+(.*)/;
    if ($tmp =~ /^macro\s+/) {
      my ($arg) = $tmp =~ /^macro\s+(.*)/;
      if ($arg =~ /^reset/) {
        $self->{error} = "error in ".$self->{line}.": use 'release' instead of 'macro reset'";
        return
      }
      if ($arg eq 'pause' || $arg eq 'resume') {
        $self->{error} = "error in ".$self->{line}.": do not use 'macro pause' or 'macro resume' within a macro";
        return
      }
      if ($arg =~ /^set\s/) {
        $self->{error} = "error in ".$self->{line}.": do not use 'macro set'. Use \$foo = bar";
        return
      }
      if ($arg !~ /^(list|status|stop)$/) {
        $self->{error} = "error in ".$self->{line}.": use 'call $arg' instead of 'macro $arg'";
        return
      }
    } elsif ($tmp =~ /^ai\s+clear$/) {
      $self->{error} = "error in ".$self->{line}.": do not mess around with ai in macros";
      return
    }
    my $result = parseCmd($tmp);
    unless (defined $result) {
      $self->{error} = "error in ".$self->{line}.": command $tmp failed";
      return
    }
    $self->{line}++;
    $self->{timeout} = $self->{macro_delay};
    return $result
  ##########################################
  # log command
  } elsif ($line =~ /^log\s+/) {
    my ($tmp) = $line =~ /^log\s+(.*)/;
    my $result = parseCmd($tmp);
    unless (defined $result) {
      $self->{error} = "error in ".$self->{line}.": $tmp failed"
    } else {
      message "[macro][log] $result\n", "macro";
    }
    $self->{line}++;
    $self->{timeout} = $self->{macro_delay}
  ##########################################
  # pause command
  } elsif ($line =~ /^pause/) {
    my ($tmp) = $line =~ /^pause\s+(\d+)/;
    if (defined $tmp) {$self->{timeout} = $tmp}
    $self->{line}++;
  ##########################################
  # stop command
  } elsif ($line =~ /^stop$/) {
    $self->{finished} = 1
  ##########################################
  # release command
  } elsif ($line =~ /^release\s+/) {
    my ($tmp) = $line =~ /^release\s+(.*)/;
    if (!releaseAM(parseCmd($tmp))) {
      $self->{error} = "error in ".$self->{line}.": releasing $tmp failed"
    }
    $self->{line}++;
    $self->{timeout} = $self->{macro_delay}
  ##########################################
  # lock command
  } elsif ($line =~ /^lock\s+/) {
    my ($tmp) = $line =~ /^lock\s+(.*)/;
    if (!lockAM(parseCmd($tmp))) {
      $self->{error} = "error in ".$self->{line}.": locking $tmp failed"
    }
    $self->{line}++;
    $self->{timeout} = $self->{macro_delay}
  ##########################################
  # call command
  } elsif ($line =~ /^call\s+/) {
    my ($tmp) = $line =~ /^call\s+(.*)/;
    if ($tmp =~ /\s/) {
      my ($name, $times) = $tmp =~ /(.*?)\s+(.*)/;
      my $ptimes = parseCmd($times);
      unless (defined $ptimes) {
        $self->{error} = "error in ".$self->{line}.": $times failed"
      } else {
        $self->{subcall} = new Macro::Script($name, $ptimes)
      }
    } else {
      $self->{subcall} = new Macro::Script($tmp)
    }
    if (!defined $self->{subcall}) {
      $self->{error} = "error in ".$self->{line}.": failed to call script"
    } else {
      $self->{subcall}->regSubmacro;
      $self->{timeout} = $self->{macro_delay}
    }
  ##########################################
  # unrecognized line
  } else {
    $self->{error} = "error in ".$self->{line}.": syntax error"
  }
  if (defined $self->{error}) {return} else {return ""}
}

1;
