package Scribbler::AtomBlock;
use strict;
use Carp qw/cluck/;
use base qw/Scribbler::Atom/;

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $parent = shift;
	my $self = Scribbler::Atom::new($class, $parent);
	$self->configure(@_);
	return $self
}

sub emitCode {
	my $self = shift;
	$self->worksheet->indentCode;
	foreach my $child ($self->children) {
		if ($child->active == 1) {
			$child->emitCode if $child->can('emitCode');
			$child->emitCall
		}
	}
	$self->worksheet->unindentCode
}

sub redraw {
	my $self = shift;
	return unless $self->worksheet;
	my ($width, $height) = (1, 0);
	my ($x, $y) = $self->location;
	foreach my $atom ($self->children) {
		$atom->location($x, $y + $height);
		my ($w, $h) = $atom->size;
		$height += $h;
		$width = $w if $w > $width
	}
	return $self->size($width, $height);
}

sub reactivate {
	my $self = shift;
	return 1 unless $self->worksheet;
	my $active = $self->SUPER::reactivate(@_);
	foreach my $atom ($self->children) {
		$active = $atom->reactivate($active);
	}
	return $self->activeOut($active >= $self->priority ? 1 : $active);
}

#------------------------------------------------------------------------

sub edit {
	my $self = shift;
	$self->begin->edit
}

sub reimage {
	my $self = shift;
	$self->begin->reimage
}

sub icon {
	my $self = shift;
	return $self->begin->icon
}

1;
