package Scribbler::TileBlock;
use strict;

sub new {
	my $invocant = shift;
	my $class = ref $invocant || $invocant;
	my $self = {};
	bless $self, $class;
	$self->link('begin', shift());
	$self->link('end', shift());
	my $payload = shift;
	$self->link('payload', $payload));
	$payload->link('parent', $self);
	return $self
}

sub clone {
	my $self = shift;
	my $begin = $self->link('begin')->clone;
	my $payload = $self->link('payload')->clone;
	my $end = $self->link('end')->clone;
	return $self->new($begin, $end, $payload)
}

sub link {
	my $self = shift;
	my $linkname = shift;
	@_ ? $self->{link}->{$linkname} = shift : $self->{link}->{$linkname}
}

sub size {
	my $self = shift;
	my ($height, $width) = $self->link('payload')->size;
	return ($height + 2, $width)
}

1;
	