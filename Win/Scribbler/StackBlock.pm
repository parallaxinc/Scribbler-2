package Scribbler::StackBlock;
use strict;
use Carp qw/croak cluck/;
use base qw/Scribbler::Atom/;

sub new {
	my $invocant = shift;
	my $class = ref $invocant || $invocant;
	my $parent = shift;
	my $self = Scribbler::Atom::new($class, $parent);
	return $self
}

sub clone {
	my $self = shift;
	my $parent = shift;
	my $clone = $self->new($parent);
	my @args;
	foreach my $i (0 .. @{$clone->child('begin')} - 1) {
		push @args, $clone->child('begin')->[$i]->clone($clone),
			$self->child('stack')->[$i]->clone($clone),
			$self->child('end')->[$i]->clone($clone)
	}
	$clone->populate(@args);
	return $clone
}

sub redraw {
	my $self = shift;
	my ($width, $height) = (0, 0);
	my ($x, $y) = $self->location;
	my @x;
	foreach my $i (0 .. @{$self->child('begin')} - 1) {
		push @x, $width;
		$self->child('begin')->[$i]->location($x + $width, $y);
		$self->child('stack')->[$i]->location($x + $width, $y + 1);
		my ($w, $h) = $self->child('stack')->[$i]->size;
		$width += $w;
		$height = $h if $h > $height;
	}
	foreach my $i (0 .. @{$self->child('begin')} - 1) {
		$self->child('end')->[$i]->location($x + $x[$i], $y + $height + 1)
	}
	$self->size($width, $height + 2)
}

sub stack {
	my $self = shift;
	my $target = shift;
	my @begin = @{$self->child('begin')};
	my @end = @{$self->child('end')};
	my $last = @begin - 1;
	return $self->parent->stack if grep {$target eq $begin[$_]} (0 .. $last);
	if (my @index = grep {$target eq $end[$_]} (0 .. $last)) {
		return $self->child('stack')->[$index[0]]
	}
	foreach my $stack (@{$self->child('stack')}) {
		return $stack if defined $stack->find($target)
	}
	return undef
}

#------------------------------------------------------------------------

sub populate {
	my $self = shift;
	my (@begin, @stack, @end);
	croak "Number of arguments to Scribbler::StackBlock->populate must be a multiple of three." if @_ % 3;
	while (@_) {
		push @begin, shift;
		push @stack, shift;
		push @end, shift;
	}
	$self->child(begin => [@begin], stack => [@stack], end => [@end]);
	$self->redraw;
	return $self
}

1;

__END__

sub begin {
	my $self = shift;
	if (ref(my $begin = $self->child('begin')) && @_) {
		return $begin = [shift]
	} else {
		return $begin
	}
}

sub stack {
	my $self = shift;
	if (ref(my $stack = $self->child('stack')) && @_) {
		return $stack = [shift]
	} else {
		return $stack
	}
}

sub end {
	my $self = shift;
	if (ref(my $end = $self->child('end')) && @_) {
		return $end = [shift]
	} else {
		return $end
	}
}

1;
	