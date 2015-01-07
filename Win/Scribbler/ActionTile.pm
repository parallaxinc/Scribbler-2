package Scribbler::ActionTile;
use strict;
use Carp;
use Scribbler::Constants;
use Scribbler::Tile;
use base qw/Scribbler::Tile/;

sub new {
 	my $invocant = shift;
 	my $class = ref($invocant) || $invocant;
 	my $parent = shift;
 	my $self = Scribbler::Tile::new($class, $parent, @_);
 	return $self
}

sub createImage {
	my $self = shift;
	$self->configure(@_) if @_;
	my $icon = $self->action('icon');
	my $wantcall = $self->action('call');
	my $realcall = $self->call || '';
	my $text = $self->action('text') || '';
	if ($icon && $wantcall || $text ne '') {
		$self->SUPER::createImage(
			tile => 'action',
			$icon ? (icon => [$icon, .6 * $XC, 25]) : (),
			$wantcall ? (icon => ["call_$realcall", 1.4 * $XC, 25]) : (),
			$text ne '' ? (text => [$text, $XC, $Y1 - 15]) : (),
			ghost => 'GREEN'
		)
	} else {
		$self->SUPER::createImage(
			tile => 'action',
			icon => [$icon || "call_$realcall", $XC, $YC],
			ghost => 'GREEN'
		)
	}		
}

1;
