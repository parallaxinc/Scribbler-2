package Scribbler::SoundLibrary;
use strict;
use Scribbler::SoundBite;
use Carp qw/cluck/;
use Data::Dump qw/dump/;

my %Scale;
my $Semitone = exp(log(2) / 12);
my $freq = 440 / $Semitone ** 9;
my $Internote = 35;
my $Staccato = 50;
my $Grace = 50;
foreach (split / /, 'C C# D Eb E F F# G Ab A Bb B') {
	$Scale{$_} = $freq;
	$freq *= $Semitone
}
$Scale{Z} = 0;

sub new {
 	my $invocant = shift;
 	my $class = ref($invocant) || $invocant;
	my $self = {soundbites => {}};
	bless $self, $class;
	return $self
}

sub readAbcFile {
	my $self = shift;
	my $filename = shift;
	my ($bite, $onemeasure, $onebeat, $notelength, $tempo, $inchord, $prvdot, $prvgrace, $inloop, $ingrace, $incond, $stacc);
	my (@freq, @fmult, @prvfreq, @prvfmult);
	my @groups;
	open ABC, "<$filename" or return 0;
	while (<ABC>) {
		#print $_;
		s/\r|\n//g;
		if (m/^%%Groups:(.*)/) {
			@groups = split /,/, $1;
			$self->{groups} = [@groups, ''];
		}elsif (m/^([A-Z]):(.*)/) {
			my $type = $1;
			my $value = $2;
			if ($type eq 'X') {
				$bite = Scribbler::SoundBite->new;
				$tempo = 240;
				$prvdot = $inchord = $incond = $inloop = $ingrace = $prvgrace = $stacc = 0;
				@prvfreq = (0);
				@prvfmult = (1);
			} elsif ($type eq 'T') {
				$bite->abbr($value)
			} elsif ($type eq 'M') {
				($onemeasure, $onebeat) = split /\//, $value
			} elsif ($type eq 'L') {
				my ($num, $denom) = split /\//, $value;
				$notelength = $num / $denom
			} elsif ($type eq 'Q') {
				if ($value =~ m/(\d+)\/(\d+)=(\d+)/) {
					$tempo = $3 *  $1 / ($2 * $notelength);
				} else {
					$tempo = $value
				}
			} elsif ($type eq 'N') {
				$bite->comment($value)
			} elsif ($type eq 'G') {
				$value = '' unless grep {$value eq $_} @groups;
				$bite->group($value)
			} elsif ($type eq 'I') {
				my @args = split /,/, $value;
				foreach (@args) {
					my ($key, $val) = split(/=/, $_);
					$bite->configure($key => $val)
				}
			}
		} elsif (m/\S/) {
			my $tremolo = $bite->tremolo;
			my $internote = $bite->internote || $Internote;
			while (m/(\|:[\d:]*)?(\[\d+)?(\{?)(\.*)(\[?)([_=\^]*\d*)([A-GZa-gz]|H\$|H\d+|P\$|P\d+)('+|,*)(\]?)(M\$|M\d+)?(\/?\d*)?(>*)(\}?)(:\|)?/g) {
			
				my ($begloop, $begcond, $beggrace, $newstacc, $begchord, $accid, $note, $octave, $endchord, $millisec, $muldiv, $dot, $endgrace, $endloop) 
					= ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14);
				
				if ($begloop && ! $inloop) {
					my @loop;
					if (my $repblock = ($begloop =~ m/\|:([\d:]+)/)[0]) {
						@loop = split /:/, $repblock
					} else {
						@loop = ()
					}
					my $reps = ([1, 2, 1], [1, $loop[0], 1], [@loop, 1], [@loop])[scalar @loop];
					$bite->addNotes(type => 'loopbegin', reps => $reps);
					$inloop = 1
				}
				
				if ($begcond && $inloop) {
					my $match = ($begcond =~ m/(\d+)/)[0];
					my $type = $incond ? 'elseif' : 'if';
					$bite->addNotes(type => $type, condition => $match);
					$incond = 1;
				}
					
				$stacc = 1 if $newstacc;
				
				$ingrace = 1 if $beggrace;

				$inchord = 1 if $begchord;
				
				my $freq = 0;
				my $type = 'note';
				
				if ($note =~ m/P([\$\d]+)/) {
					$freq = $1;
					$type = 'pulse'
				} elsif ($note =~ m/H([\$\d]+)/) {
					$freq = $1
				} else {
					$freq = $Scale{uc $note};
					$freq *= 2 if $note eq lc($note)
				}
				
				my $fmult = 1;
				$fmult *= 2 ** length($octave) if $octave =~ m/'/;
				$fmult /= 2 ** length($octave) if $octave =~ m/,/;
				if ($accid =~ m/\^(\d*)/) {
					my $mul = $1 || 0;
					$fmult *= $mul ? $mul : $Semitone
				} elsif ($accid =~ m/_(\d*)/) {
					my $div = $1 || 0;
					$fmult /= $div ? $div : $Semitone
				}
				
				my $duration;
				if ($millisec && $millisec =~ m/M([\$\d]+)/) {
					$duration = $1
				} else {
					$duration = 60000 / $tempo
				}
				
				my $dmult = 1;
				if ($muldiv =~ m/\/(\d*)/) {
					$dmult = 1 / ($1 || 2)
				} elsif ($muldiv =~ m/(\d+)/) {
					$dmult = $1
				}
				$dot = $dot ? $dmult * 0.5 ** length($dot) : 0;
				$dmult = $dmult + $dot - $prvdot;
				
				push @freq, $freq;
				push @fmult, $fmult;
				
				if (!$inchord || $endchord) {
					
					my ($f, $fm, $d, $dm, $r) = ($freq[-1], $fmult[-1], $duration, $dmult, 0);

					if ($f ne '$') {
						if ($prvfreq[-1] ne '$' && $f * $fm == $prvfreq[-1] * $prvfmult[-1]) {
							if ($bite->shortenLast($internote)) {
								$bite->addNotes(type => 'note', frequency => 0, fmult => 1, duration => $internote, dmult => 1)
							}
						}
						if (@freq > 1) {
							$f = [map {$freq[$_] * $fmult[$_]} (0 .. @freq - 1)];
							$fm = 1
						} elsif ($tremolo) {
							$f = [$freq[0] * $fmult[0], $freq[0] * $fmult[0] + $tremolo];
							$fm = 1
						} else {
							$f = $freq[0];
							$fm = $fmult[0]
						}
					}
					
					if ($d ne '$') {
						if ($ingrace) {
							$d = $Grace;
							$dm = 1;
							$prvgrace += $Grace
						} elsif ($stacc) {
							$r = $d * $dm - $Staccato - $prvgrace;
							$r = 0 if $r < 0;
							$prvgrace = 0;
							$d = $Staccato;
							$dm = 1;
							$stacc = 0
						} elsif ($prvgrace) {
							$d = $d * $dm - $prvgrace;
							$dm = 1;
							$prvgrace = 0
						}
					}
					
					$bite->addNotes(type => $type, frequency => $f, fmult => $fm, duration => $d, dmult => $dm);
					$bite->addNotes(type => 'note', frequency => 0, fmult => 1, duration => $r, dmult => 1) if $r;
					$inchord = 0;
				}					
				
				unless ($inchord) {
					$prvdot = $dot;
					@prvfreq = @freq;
					@prvfmult = @fmult;
					@freq = ();
					@fmult = ();
				}
				
				$ingrace = 0 if $endgrace;
				
				if ($endloop && $inloop) {
					$bite->addNotes(type => 'endif') if $incond;
					$bite->addNotes(type => 'loopend');
					$incond = 0;
					$inloop = 0
				}
			}
			
			$bite->addNotes(type => 'endif') if $incond;
			$bite->addNotes(type => 'loopend') if $inloop
			
		} else {
			push @{$self->{soundbites}->{$bite->group}}, $bite if ref $bite;
			#dump($bite);
			undef $bite
		}
	}
}

sub groups {
	my $self = shift;
	return @{$self->{groups}};
}

sub soundbites {
	my $self = shift;
	my @groups = @_ ? (shift) : $self->groups;
	return map {my $soundbites = $self->{soundbites}->{$_}; ref $soundbites ? @$soundbites : ()} @groups
}

1;


					
					
				
				
				
				
				