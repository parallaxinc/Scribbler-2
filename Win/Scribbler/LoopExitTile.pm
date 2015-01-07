package Scribbler::LoopExitTile;
use strict;
use Carp qw/cluck/;
use Scribbler;
use Scribbler::Constants;
use Scribbler::ExitTile;
use base qw/Scribbler::ExitTile/;

sub new {
	my $invocant = shift;
	my $parent = shift;
	my $class = ref($invocant) || $invocant;
	my $self = Scribbler::ExitTile::new($class, $parent, @_);
	$self->action(icon => 'exit');
	return $self
}

sub emitCode {
	my $self = shift;
	$self->worksheet->appendCode('quit')
}

1;

