package Scribbler::SoundBite;

use strict;
use Scribbler::Constants;
use Carp qw/cluck/;

sub new {
 	my $invocant = shift;
 	my $class = ref($invocant) || $invocant;
	my $self = {bars => 0, color => $ROOT_COLOR, notes => [], location => undef, image => undef, tremolo => 0, notelength => '1/4', notetranspose => '0'};
	bless $self, $class;
	$self->configure(@_);
	return $self
}

sub clone {
	my $self = shift;
	my $clone = $self->new;
	$clone->configure(map {$_ => $self->{$_}} (keys %$self));
	return $clone;
}

sub configure {
	my $self = shift;
	while (@_) {
		my $key = lc(shift);
		my $value = shift;
		if ($key eq 'color') {
			$self->color($value)
		} else {
			$self->{$key} = $value
		}
	}
}

sub tremolo {
	my $self = shift;
	return @_ ? $self->{tremolo} = shift : $self->{tremolo}
}
	
sub noteLength {
	my $self = shift;
	return @_ ? $self->{notelength} = shift : $self->{notelength}
}
	
sub noteTranspose {
	my $self = shift;
	return @_ ? $self->{notetranspose} = shift : $self->{notetranspose}
}
	
sub internote {
	my $self = shift;
	return @_ ? $self->{internote} = shift : $self->{internote}
}
	
sub bars {
	my $self = shift;
	return @_ ? $self->{bars} = shift : $self->{bars}
}

sub group {
	my $self = shift;
	return @_ ? $self->{group} = shift : $self->{group} || ''
}

sub location {
	my $self = shift;
	return @_ ? $self->{location} = shift : $self->{location}
}

sub size {
	my $self = shift;
	return $self->{bars} || 1
}

sub locsize {
	my $self = shift;
	return $self->location . ':' . $self->size
}

sub image {
	my $self = shift;
	return @_ ? $self->{image} = shift : $self->{image}
}

sub abbr {
	my $self = shift;
	return @_ ? $self->{abbr} = shift : $self->{abbr}
}

sub comment {
	my $self = shift;
	return @_ ? $self->{comment} = shift : $self->{comment} || ''
}

sub color {
	my $self = shift;
	if (@_) {
		my $color = lc(shift());
		my @colors = @COLORS;
		push @colors, 'black', 'white' if $self->{bars} == 1;
		$self->{color} = $color if grep {$color eq $_} (@colors);
	}
	return $self->{color};
}

sub addNotes {
	my $self = shift;
	while (@_ ) {
		my $note = shift;
		$note = {$note, splice @_, 0} unless ref $note;
		push @{$self->{notes}}, $note
	}
}

sub shortenLast {
	my $self = shift;
	my $index = -1;
	my $size = @{$self->{notes}};
	foreach (1 .. $size) {
		return 0 if $self->{notes}->[-$_]->{type} =~ m/^(if|elseif|endif)$/;
		if ($self->{notes}->[-$_]->{duration}) {
			$self->{notes}->[-$_]->{duration} -= shift() / $self->{notes}->[-$_]->{dmult};
			return 1
		}
	}
}

sub notes {
	my $self = shift;
	$self->{notes} = [@_] if @_;
	return @{$self->{notes}}
}
	
1;


