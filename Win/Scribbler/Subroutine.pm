package Scribbler::Subroutine;
use strict;
use Carp;
use Scribbler;
use Scribbler::Constants;
use Scribbler::SubroutineTile;
use Scribbler::AtomBlock;
use base qw/Scribbler::AtomBlock/;

sub new {
	my $invocant = shift;
	my $parent = shift;
	my $class = ref($invocant) || $invocant;
	my $self = Scribbler::AtomBlock::new($class, $parent, @_);
	$self->children(
		Scribbler::SubroutineTile->new($self, subclass => 'sub_begin'),
		Scribbler::SubroutineTile->new($self, subclass => 'sub_end')
	);
	$self->configure(active => 0, activecalls => 0, counters => 0);
	return $self;
}

sub emitCode {
	my $self = shift;
	my $worksheet = $self->worksheet;
	$worksheet->appendCode("PUB " . ucfirst($self->color) . "\n\n");
	$self->clearObservations;
	$self->SUPER::emitCode;
	$self->clearObservations;
	#$worksheet->appendCode('  return')
}

sub clearObservations {
	my $self = shift;
	undef $self->{observed}
}

sub observed {
	my $self = shift;
	my $sensor = shift;
	return @_ ? $self->{observed}->{$sensor} = shift : $self->{observed}->{$sensor}
}

sub color {
	my $self = shift;
	if (@_) {
		my $newcolor = shift;
		my $oldcolor = $self->{color};
		if ($oldcolor && $oldcolor ne $newcolor) {
			$self->changeColors($oldcolor, $newcolor)
		} else {
			$self->{color} = $newcolor
		}
	}
	return $self->{color}
}

sub canBe {
	my $self = shift;
	my @available = $self->worksheet->availableColors($self->color);
	return @available;
}

sub canCall {
	my $self = shift;
	my $owncolor = $self->color;
	my $ws = $self->worksheet;
	return () if $ws->totalCalls >= 128;
	my @usedcolors = $ws->subroutineColors;
	my @cancall;
	my %calls;
	foreach (@usedcolors) {
		my $from = $ws->subroutine($_);
		foreach my $to (@COLORS) {
			$calls{$_}{$to} = $from->callsTo($to);
		}
	} 
	foreach my $color (@COLORS) {
		$calls{$owncolor}{$color}++;
		$calls{$ROOT_COLOR}{$color}++;
		my @callsto = grep $calls{$ROOT_COLOR}{$_}, @COLORS;
		foreach (1 .. 3) {
			my %nextcall = ();
			foreach my $from (@callsto) {
				foreach my $to (@COLORS) {
					$nextcall{$to} = 1 if $calls{$from}{$to}
				}
			}
			@callsto = keys %nextcall;
		}
		push @cancall, $color unless @callsto;
		$calls{$owncolor}{$color}--;
		$calls{$ROOT_COLOR}{$color}--;
	}
	if (@_) {
		my $targetcolor = shift;
		return $targetcolor eq '' || (grep {$_ eq $targetcolor} @cancall) > 0
	} else {
		return @cancall
	}
}		

sub addCall {
	my ($self, $to) = @_;
	my ($colorto, $objto) = _color_obj($self, $to);
	$self->worksheet->totalCalls(+1);
	++$objto->{'callsfrom'}->{$self->color};
	++$self->{'callsto'}->{$colorto};
}

sub deleteCall {
	my ($self, $to) = @_;
	my ($colorto, $objto) = _color_obj($self, $to);
	$self->worksheet->totalCalls(-1);
	my $callsfrom = $objto->{'callsfrom'};
	my $callsto = $self->{'callsto'};
	my $colorfrom = $self->color;
	delete $callsfrom->{$colorfrom} unless --$callsfrom->{$colorfrom};
	delete $callsto->{$colorto} unless --$callsto->{$colorto};
}

sub _color_obj {
	my ($self, $to) = @_;
	ref $to ? ($to->color, $to) : ($to, $self->worksheet->subroutine($to))
}

sub addActiveCall {
	my $self = shift;
	$self->reactivate(1) unless $self->{activecalls}++
}

sub deleteActiveCall {
	my $self = shift;
	$self->reactivate(0) unless --$self->{activecalls}
}

sub callsFrom {
	my $self = shift;
	if (@_) {
		my $from = shift;
		$from = $from->color if ref $from;
		$self->{'callsfrom'}->{$from} || 0
	} else {
		grep $self->{'callsfrom'}->{$_}, @COLORS
	}
}

sub callsTo {
	my $self = shift;
	if (@_) {
		my $to = shift;
		$to = $to->color if ref $to;
		$self->{'callsto'}->{$to} || 0
	} else {
		grep $self->{'callsto'}->{$_}, @COLORS
	}
}

sub changeColors {
	my ($self, $oldcolor, $newcolor) = @_;
	$self->{color} = $newcolor if $self->{color} eq $oldcolor;
	foreach ('callsto', 'callsfrom') {
		my $hash = $self->{$_};
		if ($hash->{$oldcolor}) {
			$hash->{$newcolor} = $hash->{$oldcolor};
			delete $hash->{$oldcolor}
		}
	}
	$self->SUPER::changeColors($oldcolor => $newcolor);
	$self->redraw
}

sub priority {
	return $SUB_PRIORITY
}

sub countCounters {
	my $self = shift;
	$self->{counters} = $self->SUPER::containedCounterDepth
}

sub containedCounterDepth {
	my $self = shift;
	return $self->{counters}
}

1;

