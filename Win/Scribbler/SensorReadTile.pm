package Scribbler::SensorReadTile;
use strict;
use Carp qw/cluck confess/;
use Scribbler;
use Scribbler::Constants;
use Scribbler::AtomBlock;
use base qw/Scribbler::Tile/;

my $Default = 'line';
my @Icons = qw/line bar obstacle_ww stall  light_lll coin_flip/;
my %Calls = (
	line => 'ReadLine', bar => 'ReadBars', obstacle => 'ReadObstacle',
	stall => 'ReadStall', light => 'ReadLight', coin => 'FlipCoin'
);
my $Index = 0;
my ($Self, $Icon, $EditWindow, %Btn);
	
sub new {
 	my $invocant = shift;
 	my $class = ref($invocant) || $invocant;
 	my $parent = shift;
 	my $self = Scribbler::Tile::new($class, $parent, @_);
 	$self->action(icon => $Default);
 	return $self
}

sub emitCode {
	my $self = shift;
	$self->action('icon') =~ m/([^_]+)/;
	my $sensor = $1;
	if ($Calls{$sensor}) {
		$self->worksheet->emitCall($Calls{$sensor});
		$self->subroutine->observed($sensor => 1);
		$self->scribbler->random(0) if $sensor eq 'coin';
	}
}	

sub createImage {
	my $self = shift;
	$self->configure(@_) if @_;
	my $icon = $self->action('icon');
	$self->SUPER::createImage(
		tile => 'action',
		icon => ['binocs', .6 * $XC, $YC],
		$icon ? (icon => [$icon, 1.4 * $XC, $YC]) : (),
		ghost => 'GREEN'
	)
}

sub icon {
	return 'binocs'
}

sub editor {
	$Self = shift;
	$Icon = $Self->action('icon') || $Default;
	$EditWindow = $Self->_createEditWindow() unless $EditWindow;
	$Index = (grep {$Icon eq $Icons[$_]} (0 .. @Icons - 1))[0] || 0;
	$Self->_updateWindow();
	return $EditWindow
}

sub _createEditWindow {
	my $self = shift;
	my $scribbler = $self->scribbler;
	my $mw = $scribbler->mainwindow->Toplevel(-title => $scribbler->translate('Observe a sensor.'), -background => 'BLACK');
	$mw->withdraw;
	$scribbler->windowIcon($mw, 'binocs');
	foreach ($Default, qw/no okay/) {
		$Btn{$_} = $mw->ToggleButton(
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
			$_ eq $Default ? (
				-pressimage => $scribbler->button("multi_$_" . '_press'),
				-offimage => $scribbler->button("multi_$_" . '_release')
			) : (
				-pressimage => $scribbler->button($_ . '_press'),
				-offimage => $scribbler->button($_ . '_release'),
			),
			-command => [\&_evtClickButton, $_]
		)->pack(-side => $_ eq $Default ? 'left' : 'right')
	}
	$scribbler->tooltip($Btn{$Default}, 'Select the sensor to observe');
	$mw->Label(
		-background => $BG,
		-image => $scribbler->icon('binocs_rev'),
		-width => 60
	)->pack(-side => 'left', -expand => 1, -fill => 'both');
	return $mw
}

sub _evtClickButton {
	my $btn = shift;
	my $okay = $btn eq 'okay';
	if ($okay || $btn eq 'no') {
		$Self->action('icon', $Icon) if $okay;
		$Self->{'done'} = $btn
	} elsif ($btn eq $Default) {
		$Index = ($Index + 1) % @Icons;
		$Icon = $Icons[$Index];
		$Self->_updateWindow();
	}		
}

sub _updateWindow {
	my $self = shift;
	my $scribbler = $self->scribbler;
	$Btn{$Default}->pressimage($scribbler->button("multi_$Icon\_press"));
	$Btn{$Default}->offimage($scribbler->button("multi_$Icon\_release"))
}

1;
