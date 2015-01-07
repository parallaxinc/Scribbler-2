package Scribbler::TuneTile;
use strict;
use Carp qw/cluck confess/;
use Tk;
use Scribbler;
use Scribbler::Constants;
use Scribbler::AtomBlock;
use Scribbler::Sound;
use base qw/Scribbler::ActionTile/;

my $Default = '1.0s';

sub new {
 	my $invocant = shift;
 	my $class = ref($invocant) || $invocant;
 	my $parent = shift;
 	my $self = Scribbler::ActionTile::new($class, $parent, @_);
 	$self->action(icon => 'tune', text => '');
 	return $self
}

my ($Self, $EditWindow, $CanTune, @Tune, $Note, $Tempo, $Freq, $Duration, @Positions);
my $c = 65.4075;
my $chroma = 1.05946309;
my @Freq = map {my $f = int($c + 0.5); $c *= $chroma; $f} (1 .. 49);
my @Notes = (('C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B') x 4, 'C');
@Notes = map {"$Notes[$_] $Freq[$_]"} (0 .. @Freq - 1);
my @WhiteKeys = grep {$_ !~ m/\#|b/} @Notes;
my @BlackKeys = grep {$_ =~ m/\#|b/} @Notes;
my $Player = Scribbler::Sound->new;

sub editor {
	$Self = shift;
	@Tune = @{$Self->action('tune') || []};
	$EditWindow = $Self->_createEditWindow() unless $EditWindow;
	$Self->_updateWindow;
	return $EditWindow
}

sub _createEditWindow {
	my $self = shift;
	my $scribbler = $self->scribbler;
	my $mw = $scribbler->mainwindow->Toplevel(-title => $scribbler->translate('compose a tune', 1));
	$mw->withdraw;
	my $frame1 = $mw->Frame(-background => $BG)->pack(-side => 'top');
	
	$CanTune = $frame1->Canvas(
		-width => 600,
		-height => 370,
		-background => 'WHITE'
	)->pack(-side => 'left');
	
	$CanTune->createImage(300, 22, -image => $scribbler->icon('score'), -anchor => 'n');
	$CanTune->createImage(300, 370, -image => $scribbler->icon('piano'), -anchor => 's');
	$CanTune->createLine(80, 10, 80, 180, -fill => 'RED');
	#$CanTune->CanvasBind('<Motion>' => [\&_showCoords, Ev('x'), Ev('y')]);
	
	my ($px0, $py0, $pdxw, $pdxb, $pdxbg) = (22, 244, 19.25, 22.5, 33);
	foreach (0 .. @WhiteKeys - 1) {
		my $key = $CanTune->createRectangle(
			$px0 + $_ * 19.25 + 1, $py0 + 80, $px0 + ($_ + 1) * 19.25 - 3, $py0 + 119,
			-fill => 'RED',
			-stipple => 'transparent',
			-width => 0,
			-tags => ['pianokey']
		);
		$CanTune->bind($key, '<Enter>' => [\&_showNote, $WhiteKeys[$_]]);
		$CanTune->bind($key, '<Button-1>' => [\&_playNote, $WhiteKeys[$_]]);
	}
	foreach (0 .. @BlackKeys - 1) {
		my $octave = int($_ / 5);
		my $index = $_ % 5;
		my $offset = $index < 2 ? 0 : $pdxbg - $pdxb;
		my $cx = $px0 + (7 * $octave + 1.5) * $pdxw + ($index - 0.5) * $pdxb + $offset - 1;
		my $key = $CanTune->createRectangle(
			$cx - 8, $py0, $cx + 8, $py0 + 76,
			-fill => 'RED',
			-stipple => 'transparent',
			-width => 0,
			-tags => ['pianokey']
		);
		$CanTune->bind($key, '<Enter>' => [\&_showNote, $BlackKeys[$_]]);
		$CanTune->bind($key, '<Button-1>' => [\&_playNote, $BlackKeys[$_]]);
	}
	$CanTune->bind('pianokey', '<Leave>' => sub {$Note = ''; $CanTune->configure(-cursor => 'left_ptr')});		 
	$CanTune->bind('pianokey', '<ButtonRelease-1>' => sub {$Player->stop});		 
	
	my $frame2 = $mw->Frame(-background => $BG)->pack(-padx => 2, -pady => 2, -side => 'bottom', -expand => 1, -fill => 'x');
	
	$frame2->Label(
		-background => $BG,
		-foreground => 'CYAN',
		-textvariable => \$Note,
		-font => $Self->scribbler->font('bigfont')
	)->pack(-side => 'left', -expand => 1, -fill => 'x');
	
	foreach (qw/no okay/) {
		$frame2->ToggleButton(
			-width => $BTN_SZ,
			-height => $BTN_SZ,
			-ontrigger => 'release',
			-latching => 0,
			-onrelief => 'flat',
			-offrelief => 'flat',
			-pressrelief => 'flat',
			-onbackground => $BG,
			-offbackground => $BG,
			-borderwidth => 0,
			-pressimage => $scribbler->button($_ . '_press'),
			-offimage => $scribbler->button($_ . '_release'),
			-command => [\&_evtClickButton, $_]
		)->pack(-side => 'right', -anchor => 'e')
	}
	return $mw
}

sub _evtClickButton {
	my $btn = shift;
	$Self->action(tune => [@Tune]) if $btn eq 'okay';
	$Self->{'done'} = $btn
}

sub _showNote {
	my $canvas = shift;
	$Note = shift;
	$canvas->configure(-cursor => 'hand2')
}

sub _playNote {
	my $note = ($_[1] =~ m/(\d+)/)[0];
	$Player->play([$note, 5])
}	

sub _showCoords {
	my (undef, $x, $y) = @_;
	$Note = "$x, $y"
}

sub _updateWindow {
}

1;
