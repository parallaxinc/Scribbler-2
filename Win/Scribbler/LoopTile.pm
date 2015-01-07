package Scribbler::LoopTile;
use strict;
use Carp;
use Scribbler::Constants;
use Scribbler::Tile;
use Tk;
use Tk::Canvas;
use base qw/Scribbler::Tile/;

my ($Self, $Reps, $EditWindow, $canCounter, @imgDigits, $RepsOkay);

sub new {
 	my $invocant = shift;
 	my $class = ref($invocant) || $invocant;
 	my $parent = shift;
 	my $self = Scribbler::Tile::new($class, $parent, @_)
}

sub createImage {
	my $self = shift;
	$self->configure(@_) if @_;
 	my $subclass = $self->subclass;
	$self->SUPER::createImage(
 		tile => "$subclass",
 		$subclass eq 'loop_begin' ? (text => [$self->action('reps') || '', $XC, $Y1 - 15, 'WHITE']) : (),
 		ghost => 'BLUE'
 	)
}

sub editor {
	$Self = shift;
	$EditWindow = $Self->_createEditWindow() unless $EditWindow;
	$Reps = $Self->action('reps');
	if ($Reps) {
		$RepsOkay = 1
	} else {
		my $counterdepth = $Self->counterDepth;
		my $subcounterdepth = $Self->subroutine->containedCounterDepth;
		$RepsOkay = $counterdepth < $subcounterdepth || $Self->worksheet->counters < $LOOP_COUNTER_LIMIT
	}
	$canCounter->itemconfigure('lights_out', state => $Reps ? 'hidden' : 'normal');
	$Self->_updateWindow();
	return $EditWindow
}

sub _createEditWindow {
	my $self = shift;
	my $scribbler = $self->scribbler;
	my $mw = $scribbler->mainwindow->Toplevel(-title => $scribbler->translate('loop counter', 1), -background => $BG);
	$mw->withdraw;
	$scribbler->windowIcon($mw, 'loop');
	$canCounter = $mw->Canvas(
		-background => $BG,
		-borderwidth => 0,
		-width => 184,
		-height => 94
	)->pack(-side => 'top');
	$canCounter->createImage(0, 0, -image => $scribbler->icon('counter'), -anchor => 'nw', -tags => 'lights_on');
	$canCounter->createImage(53, 48, -image => $scribbler->counter('0'), -tags => ['digit_0', 'lights_on']);
	$canCounter->createImage(92, 48, -image => $scribbler->counter('0'), -tags => ['digit_1', 'lights_on']);
	$canCounter->createImage(131, 48, -image => $scribbler->counter('0'), -tags => ['digit_2', 'lights_on']);
	$canCounter->createImage(0, 0, -image => $scribbler->icon('counter_dark'), -anchor => 'nw', -tags => 'lights_out');
	$scribbler->tooltip(
		$canCounter,
		{lights_on => 'Select number of repetitions. "000" disables counter and loops forever.'}
	);
	$scribbler->toolWarning(
		$canCounter,
		{lights_out => 'No more loop counters are available. "Loop forever" is still okay.'}
	);
	foreach (qw/no okay/) {
		$mw->ToggleButton(
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
		)->pack(-side => 'right', -pady => 2, -padx => 2)
	}
	$canCounter->CanvasBind('<Enter>' => sub {$canCounter->itemconfigure('lights_out', state => 'hidden') if $RepsOkay && $Reps == 0});
	$canCounter->CanvasBind('<Leave>' => sub {$canCounter->itemconfigure('lights_out', state => 'normal') if $Reps == 0});
	$canCounter->CanvasBind('<Button-1>' => [\&_evtUpDown, Ev('x'), Ev('y')]);
	return $mw
}

sub _evtUpDown {
	my ($canvas, $x, $y) = @_;
	return unless $RepsOkay && (my $dir = $y < 42 ? 1 : $y > 54 ? -1 : 0);
	my $index = Scribbler::floor(($x - 33) / 39);
	if ($index >= 0 and $index <= 2) {
		$dir *= 10 ** (2 - $index);
		$Reps += $dir;
		$Reps -= $dir if $Reps < 0 || $Reps > 255;
		$Self->_updateWindow
	}
}

sub _evtClickButton {
	my $btn = shift;
	my $okay = $btn eq 'okay';
	if ($okay || $btn eq 'no') {
		$Self->action('reps', $Reps) if $okay;
		$canCounter->itemconfigure('lights_out', state => 'normal');
		$Self->{'done'} = $btn
	}		
}

sub _updateWindow {
	my $self = shift;
	my @indices = @_ ? (shift()) : (0 .. 2);
	my $scribbler = $self->scribbler;
	my @digits = split //, sprintf('%3.3d', $Reps);
	foreach my $index (@indices) {
		$canCounter->itemconfigure("digit_$index", -image => $scribbler->counter($digits[$index]))
	}
}

1;
