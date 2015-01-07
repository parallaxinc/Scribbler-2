package Scribbler::SoundPlayer;
use strict;
use Win32::Sound;

my $Rate = 8000; my $Longest = 0; my $Silence = pack('C', 128); my $High = pack('C', 250); my $Low = pack('C', 1);

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $self = {player => Win32::Sound::WaveOut->new($Rate, 8, 1)};
	bless $self, $class;
	return $self
}

sub play {
	my $self = shift;
	my $player = $self->{player};
	$self->stop;
	my $data = '';
	my $phase = 0;
	my @f;
	
	foreach (@_) {
		my ($type, $duration, $dmult, $freq, $fmult) = @$_;
		$duration *= $dmult / 1000;
		
		if ($type eq 'pulse') {
			my $period = ($freq * $fmult + 1000)/ 1e6 + $duration;
			@f = (1 / $period);
			$duration = $period;
		} else {
			if (ref $freq) {
				@f = ($freq->[0] * $fmult, $freq->[1] * $fmult)
			} else {
				@f = ($freq * $fmult)
			}
		}


		my $auxils = $duration * $Rate + $phase;
		my $iauxils = int($auxils);
		
		foreach my $t (0 .. $iauxils - 1) {
			my $v = 0;
			$v += _cliptriangle(($t * $_ - $phase)/ $Rate * 256) foreach @f;
			$v = 128 + 127 * $v / @f;
			$data .= pack('C', $v)
		}
		
		$phase = $auxils - $iauxils
	}
	
	my $len = length($data);
	if ($len > $Longest) {
		$Longest = $len
	} else {
		$data .= $Silence x ($Longest - $len);
	}
	$player->Load($data);
	$player->Write;
}

sub playBites {
	my $self = shift;
	my $tempo = shift;
	my @sequence;
	my $reps = undef;
	my ($from, $to, $step);
	my @loop;
	while (@_) {
		my $bite = shift;
		my $notelength = eval($bite->noteLength) * 4;
		my $notetranspose = 1.059463094 ** ($bite->noteTranspose);
		foreach my $note ($bite->notes) {
			my $type = $note->{type};
			if ($type eq 'loopbegin' && !$reps) {
				$reps = $note->{reps};
				($from, $to, $step) = @$reps;
			} elsif ($type eq 'loopend' && $reps) {
				my $counter = $from;
				while (1) {
					my $condition = 0;
					foreach my $nt (@loop) {
						if ($nt->[0] eq 'if') {
							$condition = $nt->[1];
						} elsif ($nt->[0] eq 'endif') {
							$condition = 0
						} elsif ($condition == 0 || $counter == $condition) {
							my $nnt = [@$nt];
							$nnt->[1] = $counter if $nt->[1] eq '$';
							$nnt->[3] = $counter if $nt->[3] eq '$';
							push @sequence, $nnt
						}
					}
					if ($from > $to) {
						$counter -= $step;
						last if $counter < $to
					} else {
						$counter += $step;
						last if $counter > $to
					}
				}
				@loop = ();
				$reps = undef
			} elsif ($type =~ /^(if|elseif)$/) {
				push @loop, ['if', $note->{condition}]
			} elsif ($type eq 'endif') {
				push @loop, ['endif']
			} elsif ($type =~ /^(note|pulse)$/) {
				my $freq = $note->{frequency} || 0;
				my $fmult = $note->{fmult} || 1;
				$fmult *= $notetranspose;
				my $duration = $note->{duration} || 0;
				my $dmult = $note->{dmult} || 1;
				$dmult *= $notelength / $tempo;
				if ($reps) {
					push @loop, [$type, $duration, $dmult, $freq, $fmult]
				} else {
					push @sequence, [$type, $duration, $dmult, $freq, $fmult]
				}
			}
		}
	}
	$self->play(@sequence)
}	

sub done {
	my $self = shift;
	return $self->{player}->Status
}

sub stop {
	my $self = shift;
	my $player = $self->{player};
	$player->Reset;
	$player->Unload
}

sub volume {
	my $self = shift;
	my $volume = shift;
	Win32::Sound::Volume($volume * 0x2020202)
}

#---[Functions for different waveforms]------------------------------

sub _duo {
	my $x = shift;
	$x *= 6.2831854 / 256;
	return (sin($x) + 0.5 * sin(3 * $x) + 0.25 * sin(5 * $x)) / 1.75
}

sub _square {
	my $x = (int(shift) % 256);
	$x += 256 if $x < 0;
	return $x < 128 ? -1 : 1
}

sub _triangle {
	my $x = (int(shift) % 256);
	$x += 256 if $x < 0;
	return $x < 128 ? $x / 128 - 0.5 : (256 - $x) / 128 - 0.5
}

sub _cliptriangle {
	my $x = shift;
	$x += 256 if $x < 0;
	return -1 if $x % 256 > 128;
	my $y = _triangle(2 * $x) * 2;
	return $y > 1 ? 1 : $y < -1 ? -1 : $y
}

1;