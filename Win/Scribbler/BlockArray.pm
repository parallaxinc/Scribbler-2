package Scribbler::BlockArray;
use strict;
use Scribbler::Constants;
use Carp qw/cluck/;
use base qw/Scribbler::AtomBlock/;

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $parent = shift;
	my $self = Scribbler::AtomBlock::new($class, $parent, vectors => []);
	return $self
}

sub emitCode {
	my $self = shift;
	foreach my $child ($self->children) {
		if ($child->active == 1) {
			$child->emitCode if $child->can('emitCode');
			$child->emitCall
		}
	}
}

sub redraw {
	my $self = shift;
	return unless $self->worksheet;
	my $canvas = $self->canvas;
	my ($width, $height) = (0, 0);
	my ($x, $y) = $self->location;
	foreach my $block ($self->children) {
		$block->location($x + $width, $y);
		my ($w, $h) = $block->size;
		$width += $w;
		$height = $h if $h > $height;
	}
	$self->size($width, $height)
}

sub reactivate {
	my $self = shift;
	return 1 unless $self->worksheet;
	my $activein = $self->Scribbler::Atom::reactivate(@_);
	my $activeout = 0;
	foreach my $block ($self->children) {
		my $active = $block->reactivate($activein);
		$activeout = $active if $active > $activeout
	}
	$self->redraw;
	return $self->activeOut($activeout >= $self->priority ? 1 : $activeout)
}

sub insertBefore_old {
	my ($self, undef, $atom) = @_;
	$self->parent->insertBefore($self, $atom)
}

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

#------------------------------------------------------------------------

1;
	