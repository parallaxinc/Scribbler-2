package Scribbler::LedTile;
use strict;
use Carp qw/cluck confess/;
use Scribbler;
use Scribbler::Constants;
use Scribbler::AtomBlock;
use base qw/Scribbler::Tile/;

my $Default = 'on';

sub new {
 	my $invocant = shift;
 	my $class = ref($invocant) || $invocant;
 	my $parent = shift;
 	my $self = Scribbler::Tile::new($class, $parent, @_);
 	$self->action(states => [($Default) x 3]);
 	return $self
}

sub emitCode {
	my $self = shift;
	my $worksheet = $self->worksheet;
	my @states = @{$self->action('states')};
	my $code = "s2.set_leds(";
	foreach (0 .. 2) {
		$code .= 's2#' . ($states[$_] eq 'on' ? 'GREEN, ' : ($states[$_] eq 'off' ? 'OFF, ' : 'NO_CHANGE, '))
	}
	$worksheet->appendCode($code . 's2#NO_CHANGE)')
}

sub createImage {
	my $self = shift;
	$self->configure(@_) if @_;
	my @states = @{$self->action('states')};
	$self->SUPER::createImage(
		tile => 'action',
		icon => ["led_$states[0]", $XC - 20, $YC],
		icon => ["led_$states[1]", $XC, $YC],
		icon => ["led_$states[2]", $XC + 20, $YC],
		ghost => 'GREEN'
	)
}

sub icon {
	return 'leds'
}

my ($Self, $EditWindow, @Index, $CanLed);

my @States = qw/on off na off/;

sub editor {
	$Self = shift;
	my @states = @{$Self->action('states') || [($Default) x 3]};
	$EditWindow = $Self->_createEditWindow() unless $EditWindow;
	foreach my $led (0 .. 2) {
		$Index[$led] = (grep {$states[$led] eq $States[$_]} (0, 2, 3))[0] || 0
	}
	$Self->_updateWindow(0 .. 2);
	return $EditWindow
}

sub _createEditWindow {
	my $self = shift;
	my $scribbler = $self->scribbler;
	my $mw = $scribbler->mainwindow->Toplevel(-title => $scribbler->translate('switch LEDs on/off', 1), -background => $BG);
	$mw->withdraw;
	$scribbler->windowIcon($mw, 'leds');
	my $frame1 = $mw->Frame(-background => $BG, -highlightthickness => 0)->pack(-side => 'top');
	
	$CanLed = $frame1->Canvas(
		-width => 230,
		-height => 214,
		-background => '#191932',
		-highlightthickness => 0
	)->pack;
	
	foreach (0 .. 2) {
		my $x = 115 + ($_ - 1) * 71;
		$CanLed->createImage(
			$x, 109,
			-image => $scribbler->icon("sw_led_$Default"),
			-tags => ["switch_$_"]
		);
		$CanLed->bind("switch_$_", '<Button-1>', [\&_evtFlipSwitch, $_])
	}
	
	my $frame2 = $frame1->Frame(-background => $BG, -highlightthickness => 0)->pack(-padx => 2, -pady => 2, -side => 'bottom', -expand => 1, -fill => 'x');
	
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
			-cursor => 'hand2',
			-pressimage => $scribbler->button($_ . '_press'),
			-offimage => $scribbler->button($_ . '_release'),
			-command => [\&_evtClickButton, $_]
		)->pack(-side => 'right', -anchor => 'e')
	}
	return $mw
}

sub _evtClickButton {
	my $btn = shift;
	$Self->action('states', [map {$States[$Index[$_]]} (0 .. 2)]) if $btn eq 'okay';
	$Self->{'done'} = $btn
}

sub _evtFlipSwitch {
	my ($canvas, $sw) = @_;
	$Index[$sw] = ($Index[$sw] + 1) % @States;
	$Self->_updateWindow($sw)
}

sub _updateWindow {
	my $self = shift;
	my $scribbler = $self->scribbler;
	foreach my $sw (@_) {
		my $state = $States[$Index[$sw]];
		$CanLed->itemconfigure("switch_$sw", -image => $scribbler->icon("sw_led_$state"));
	}		
}

1;



