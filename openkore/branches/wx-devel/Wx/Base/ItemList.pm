package Interface::Wx::Base::ItemList;

use strict;
use base 'Interface::Wx::Base::List';

use Wx ':everything';

use Globals qw/%equipTypes_lut %itemsDesc_lut %shop/;
use Misc qw/items_control pickupitems/;
use Translation qw/T TF/;
use Utils qw/formatNumber/;

sub new {
	my ($class, $parent, $id) = (shift, shift, shift);
	
	my $self = $class->SUPER::new ($parent, $id, @_);
	
	$self->{list}->InsertColumn(0, do {
		local $_ = Wx::ListItem->new;
		$_->SetAlign(wxLIST_FORMAT_RIGHT);
		$_->SetWidth(26);
	$_ });
	$self->{list}->InsertColumn(1, do {
		local $_ = Wx::ListItem->new;
		$_->SetAlign(wxLIST_FORMAT_RIGHT);
		$_->SetWidth(50);
	$_ });
	$self->{list}->InsertColumn(2, do {
		local $_ = Wx::ListItem->new;
		$_->SetWidth(150);
	$_ });
	$self->{list}->InsertColumn(3, do {
		local $_ = Wx::ListItem->new;
		$_->SetAlign(wxLIST_FORMAT_RIGHT);
		$_->SetWidth(150);
	$_ });
	
	$self->{color} = {
		usable => new Wx::Colour('DARK GREEN'),
		equip => new Wx::Colour('FIREBRICK'),
		card => new Wx::Colour('BLUE'),
		notIdent => new Wx::Colour('DARK GREY'),
		other => new Wx::Colour('BLACK'),
	};
	
	return $self;
}

sub setItem {
	my ($self, $index, $item) = @_;
	
	if ($item and my $amount = $item->{amount} || $item->{quantity}) {
		$self->SUPER::setItem($index, [
			$index,
			$item->{sold} ? sprintf('%s/%s', $amount - $item->{sold}, $amount) : $amount,
			!$item->{identified} ? TF('%s (Not identified)', $item->{name}) :
			$item->{equipped} ? ($equipTypes_lut{$item->{equipped}}
				? TF('%s (%s)', $item->{name}, $equipTypes_lut{$item->{equipped}})
				: TF('%s (Equipped)', $item->{name})
			) :
			$item->{name},
			$item->{price} ? formatNumber($item->{price}) : '',
		], (
			!$item->{identified} ? $self->{color}{notIdent}
			: $item->usable ? $self->{color}{usable}
			: $item->equippable ? $self->{color}{equip}
			: $item->mergeable ? $self->{color}{card}
			: $self->{color}{other}
		));
	} else {
		$self->SUPER::setItem($index);
	}
}

1;
