package Scribbler::AtomStack;
use strict;
use Carp qw/cluck/;
use base qw/Scribbler::Atom/;

sub new {
	my $invocant = shift;
	my $class = ref $invocant || $invocant;
	my $parent = shift;
	my $self = Scribbler::Atom::new($class, $parent);
	$self->child(atoms => [@_]);
	return $self
}

sub clone {
	my $self = shift;
	my $parent = shift;
	my $clone = $self->new($parent);
	my @stack = map {$_->clone($self)} @{$self->child('stack')};
	$clone->child(stack => [@stack]);
	return $clone
}

sub redraw {
	my $self = shift;
	my ($width, $height) = (1, 0);
	my ($x, $y) = $self->location;
	foreach my $atom (@{$self->child('atoms')}) {
		$atom->location($x, $y + $height);
		my ($w, $h) = $atom->size;
		$height += $h;
		$width = $w if $w > $width
	}
	return $self->size($width, $height);
}

sub stack {
	return shift
}

sub active {
	my $self = shift;
	if (@_) {
		my $active = shift;
		my $force = shift || 0;
		$self->{active} = $active;
		foreach my $child ($self->children) {
			$child->active($active, $force);
			$active = 0 if $child->subclass eq 'exit'
		}
	}
}

#------------------------------------------------------------------------

sub extract {
	my $self = shift;
	my @range = $self->subrange(@_);
	if (@range) {
		my @atoms = splice @{$self->child('atoms')}, $range[0], $range[1] - $range[0] + 1;
		$_->orphan foreach @atoms;
		$self->redraw;
		return @atoms
	} else {
		return ()
	}
}

sub insertBefore {
	my $self = shift;
	my $atoms = $self->child('atoms');
	my $before = shift;
	$_->parent($self) foreach @_;
	if (my $pos = $self->find($before)) {
		splice @$atoms, $pos, 0, @_
	} else {
		push @$atoms, @_
	}
	$self->active($self->active);
	$self->redraw;
	return @$atoms
}	

sub substack {
	my $self = shift;
	my @range = $self->subrange(@_);
	return @range ? @{$self->child('aotms')}[$range[0] .. $range[1]] : ()
}

sub subrange {
	my $self = shift;
	my ($from, $to) = (0, @{$self->{atoms}} - 1);
	$from = $self->find(shift()) if @_;
	$to = $self->find(shift()) if @_;
	return defined $from && defined $to && $to >= $from ? ($from, $to) : ()
}	

sub find {
	my $self = shift;
	my $target = shift;
	my @atoms = @{$self->child('atoms')};
	return (grep {$atoms[$_] eq $target} (0 .. @atoms - 1))[0];
}

1;
	
	
		
