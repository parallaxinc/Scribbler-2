package Scribbler::Loop;
use strict;
use Carp qw/cluck/;
use Scribbler;
use Scribbler::Constants;
use Scribbler::LoopTile;
use Scribbler::AtomBlock;
use base qw/Scribbler::AtomBlock/;

sub new {
	my $invocant = shift;
	my $parent = shift;
	my $class = ref($invocant) || $invocant;
	my $self = Scribbler::AtomBlock::new($class, $parent, @_);
	$self->children(
		Scribbler::LoopTile->new($self, subclass => 'loop_begin', action => {reps => 0}),
		Scribbler::LoopTile->new($self, subclass => 'loop_end')
	);
	return $self
}

sub emitCode {
	my $self = shift;
	my $worksheet = $self->worksheet;
	my $begin = $self->begin;
	my $reps = $begin->action('reps');
	if ($reps) {
		my $counter = $worksheet->nextCounter;
		$worksheet->appendCode("repeat $reps");
	} else {
		$worksheet->appendCode("repeat")
	}
	$self->subroutine->clearObservations;
	$self->SUPER::emitCode;
}

sub priority {
	return $LOOP_PRIORITY
}

sub action {
	my $self = shift;
	return $self->begin->action(@_)
}

sub icon {
	return 'loop'
}

1;
