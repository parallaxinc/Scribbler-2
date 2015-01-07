package Scribbler::Sound;
use strict;
use Win32::Sound;

my $Rate = 10000;

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
	my $silence = pack('CC', 128, 128);
	my $data = '';
	foreach (@_) {
		my ($freq, $dur) = @$_;
		$dur *= $Rate;
		if ($freq == 0) {
			$data .= $silence x ($dur)
		} else {
			foreach (0 .. $dur - 1) {
				my $v = 128 + 127 * duo($_ * $freq / $Rate * 6.2831854);
				#my $v = 128 + 127 * cliptriangle($_ * $freq / $Rate * 256);
				$data .= pack("C", $v)
			}
		}
	}
	$player->Load($data);
	$player->Volume('25%');
	$player->Write;
}

sub duo {
	my $x = shift;
	return (sin($x) + 0.5 * sin(3 * $x) + 0.25 * sin(5 * $x)) / 1.75
}

sub square {
	my $x = (int(shift) % 256);
	return $x < 128 ? -1 : 1
}

sub triangle {
	my $x = (int(shift) % 256);
	return $x < 128 ? $x / 128 - 0.5 : (256 - $x) / 128 - 0.5
}

sub cliptriangle {
	my $x = shift;
	my $y = triangle($x) * 1.25;
	return $y > 1 ? 1 : $y < -1 ? -1 : $y
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

1;