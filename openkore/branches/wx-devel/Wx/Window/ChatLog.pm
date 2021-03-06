package Interface::Wx::Window::ChatLog;
use strict;

use Wx ':everything';
use Wx::Event ':everything';
use base 'Interface::Wx::Base::LogView';

use Translation qw/T TF/;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new($parent, $id);
	
	$self->{title} = T('Chat Log');
	
	Scalar::Util::weaken (my $weak = $self);
	
	$self->addColor("selfchat", 0, 148, 0);
	$self->addColor("pm", 142, 120, 0);
	$self->addColor("p", 164, 0, 143);
	$self->addColor("g", 0, 177, 108);
	$self->addColor("warning", 214, 93, 0);
	
	my $hook = sub { $weak->onChatAdd(@_) };
	$self->{hooks} = Plugins::addHooks(
		['ChatQueue::add',  $hook],
		['packet_selfChat', $hook],
		['packet_privMsg',  $hook],
		['packet_sentPM',   $hook],
	);
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	Plugins::delHooks($self->{hooks});
}

sub onChatAdd {
	my ($self, $hook, $params) = @_;
	my @tmpdate = localtime();
	if ($tmpdate[1] < 10) {$tmpdate[1] = "0".$tmpdate[1]};
	if ($tmpdate[2] < 10) {$tmpdate[2] = "0".$tmpdate[2]};

	if ($hook eq "ChatQueue::add" && $params->{type} ne "pm") {
		my $msg = '';
		if ($params->{type} ne "c") {
			$msg = "[$params->{type}] ";
		}
		$msg .= "[$tmpdate[2]:$tmpdate[1]] $params->{user}: $params->{msg}\n";
		$self->add($msg, $params->{type});

	} elsif ($hook eq "packet_selfChat") {
		# only display this message if it's a real self-chat
		$self->add("[$tmpdate[2]:$tmpdate[1]] $params->{user}: $params->{msg}\n", "selfchat") if ($params->{user});
	} elsif ($hook eq "packet_privMsg") {
		$self->add("([$tmpdate[2]:$tmpdate[1]] From: $params->{privMsgUser}): $params->{privMsg}\n", "pm");
	} elsif ($hook eq "packet_sentPM") {
		$self->add("([$tmpdate[2]:$tmpdate[1]] To: $params->{to}): $params->{msg}\n", "pm");
	}
}

1;
