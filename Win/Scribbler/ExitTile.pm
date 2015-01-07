package Scribbler::ExitTile;
use strict;
use Carp qw/cluck/;
use Scribbler;
use Scribbler::Constants;
use Scribbler::Tile;
use Scribbler::Loop;
use base qw/Scribbler::Tile/;

sub new {
	my $invocant = shift;
	my $parent = shift;
	my $class = ref($invocant) || $invocant;
	my $self = Scribbler::Tile::new($class, $parent, subclass => 'exit', @_);
	return $self
}

sub createImage {
	my $self = shift;
	$self->configure(@_) if @_;
	my $icon = $self->action('icon');
	$self->SUPER::createImage(
		tile => 'exit',
		icon => [$self->action('icon'), $XC, $YC - 4],
		ghost => 'GREEN'
	)
}

sub reactivate {
	my $self = shift;
	return 1 unless $self->worksheet;
	my $active = $self->SUPER::reactivate(@_);
	my $priority = $self->priority;
	return $active < $priority ? $active : $priority
}

sub priority {
	return Scribbler::Loop->priority
}

1;
