package Scribbler::PauseTile;
use strict;
use Carp qw/cluck confess/;
use Scribbler;
use Scribbler::Constants;
use Scribbler::AtomBlock;
use base qw/Scribbler::ActionTile/;

my $Default = '1.0s';

sub new {
 	my $invocant = shift;
 	my $class = ref($invocant) || $invocant;
 	my $parent = shift;
 	my $self = Scribbler::ActionTile::new($class, $parent, @_);
 	$self->action(icon => 'pause', text => '1.0s', call => '');
 	return $self
}

sub emitCode {
	my $self = shift;
	my $pause = $self->action('text');
	$pause =~ s/s//;
	if ($pause < 1) {
		$pause = int(80e6 * $pause + 0.5);
		$self->worksheet->appendCode("waitcnt(cnt + $pause)");
	} else {
		$pause = int($pause * 10 + 0.5);
		$self->worksheet->appendCode("s2.delay_tenths($pause)")
	}
}	

my ($Self, $EditWindow, $CanPause, %BtnPause, $Index, @Times, $Time, @CanCall, $CallIndex);

foreach (1 .. 330) {
	if ($_ <= 99) {
		push @Times, sprintf('%5.3fs', $_ / 1000)
	} elsif ($_ <= 189) {
		push @Times, sprintf('%4.2fs', ($_ - 90) / 100)
	} elsif ($_ <= 279) {
		push @Times, sprintf('%3.1fs', ($_ - 180) / 10)
	} else {
		push @Times, sprintf('%2.1ds', $_ - 270)
	}
}

sub editor {
	$Self = shift;
	my $time = $Self->action('text') || $Default;
	$Index = (grep {$time eq $Times[$_]} (0 .. @Times - 1))[0];
	@CanCall = ('', $Self->subroutine->canCall);
	$CallIndex = (grep $CanCall[$_] eq $Self->action('call'), (0 .. @CanCall - 1))[0] || 0;
	$EditWindow = $Self->_createEditWindow() unless $EditWindow;
	_updateCall();
	$Self->_updateWindow;
	return $EditWindow
}

sub _createEditWindow {
	my $self = shift;
	my $scribbler = $self->scribbler;
	my $mw = $scribbler->mainwindow->Toplevel(-title => $scribbler->translate('wait awhile', 1));
	$mw->withdraw;
	$scribbler->windowIcon($mw, 'pause_light');
	my $frame1 = $mw->Frame(-background => $BG)->pack(-side => 'top');
	
	$CanPause = $frame1->Canvas(
		-width => 170,
		-height => 200,
		-background => '#191932'
	)->pack(-side => 'left');
	
	$CanPause->createImage(85, 10, -image => $scribbler->icon('hourglass'), -anchor => 'n');
	$CanPause->createImage(85, 65, -image=>$scribbler->icon('sand_top'), -tags => ['sand_top']);
	$CanPause->createImage(85, 10, -image => $scribbler->icon('hourglass_cut'), -anchor => 'n');
	$CanPause->createImage(85, 185, -image=>$scribbler->icon('sand_bottom'), -tags => ['sand_bottom']);
	$CanPause->createImage(85, 10, -image => $scribbler->icon('hourglass_cut_cut'), -anchor => 'n');
	
	my $scaTime = $frame1->Scale(
		-background => '#556666',
		-activebackground => '#00EEEE',
		-troughcolor => $BG,
		-command => \&_evtChangeSlider,
		-to => 0,
		-from => @Times - 1,
		-relief => 'sunken',
		-width => $SLIDER_WIDTH,
		-sliderlength => $SLIDER_LENGTH,
		-showvalue => 0,
		-variable => \$Index
	)->pack(-side => 'right', -padx => 2, -pady => 2, -expand => 1, -fill => 'y');
	$scribbler->tooltip($scaTime, 'Time delay');

	my $frame2 = $mw->Frame(-background => $BG)->pack(-padx => 2, -pady => 2, -side => 'bottom', -expand => 1, -fill => 'x');
	
	foreach (qw/call_ no okay/) {
		$BtnPause{$_} = $frame2->ToggleButton(
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
			$_ eq 'call_' ? (
				-pressimage => $scribbler->button("multi_$_" . '_push'),
				-offimage => $scribbler->button("multi_$_" . '_off')
			) : (
				-pressimage => $scribbler->button($_ . '_press'),
				-offimage => $scribbler->button($_ . '_release'),
			),
			-command => [\&_evtClickButton, $_]
		)->pack($_ eq 'call_' ? (-side => 'left', -anchor => 'w') : (-side => 'right', -anchor => 'e'))
	}
	$scribbler->tooltip($BtnPause{call_}, 'Select subroutine to call.');

	$frame2->Label(
		-background => $BG,
		-foreground => 'CYAN',
		-textvariable => \$Time,
		-font => $Self->scribbler->font('tilefont')
	)->pack(-side => 'left', -expand => 1, -fill => 'x');
	
	return $mw
}

sub _evtClickButton {
	my $btn = shift;
	if ($btn =~ m/okay|no/) {
		$Self->action(text => $Time, call => $CanCall[$CallIndex]) if $btn eq 'okay';
		$Self->{'done'} = $btn
	} elsif ($btn eq 'call_') {
		$CallIndex = ($CallIndex + 1) % scalar(@CanCall);
		_updateCall()
	}		
}

sub _updateCall {
	my $scribbler = $Self->scribbler;
	$BtnPause{'call_'}->pressimage($scribbler->button("multi_call_$CanCall[$CallIndex]" . ($CallIndex ? '_pushon' : '_push')));
	$BtnPause{'call_'}->offimage($scribbler->button("multi_call_$CanCall[$CallIndex]" . ($CallIndex ? '_on' : '_off')));
}

sub _evtChangeSlider {
	_updateWindow()
}

sub _updateWindow {
	$Time = $Times[$Index];
	$CanPause->coords('sand_top', 85, 131 - 50 * $Index / @Times);
	$CanPause->coords('sand_bottom', 85, 146 + 45 * $Index / @Times);
}

1;
