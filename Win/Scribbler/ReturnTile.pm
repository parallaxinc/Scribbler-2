package Scribbler::ReturnTile;
use strict;
use Carp qw/cluck/;
use Scribbler;
use Scribbler::Constants;
use Scribbler::ExitTile;
use Scribbler::Subroutine;
use base qw/Scribbler::ExitTile/;

sub new {
	my $invocant = shift;
	my $parent = shift;
	my $class = ref($invocant) || $invocant;
	my $self = Scribbler::ExitTile::new($class, $parent, @_);
	$self->action(icon => 'return');
	return $self
}

sub emitCode {
	my $self = shift;
	my $worksheet = $self->worksheet;
	$worksheet->appendCode('return')
}

sub priority {
	return Scribbler::Subroutine->priority
}

1;

