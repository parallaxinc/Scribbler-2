package Scribbler::CallTile;
use strict;
use Carp;
use Scribbler::Constants;
use Scribbler::ActionTile;
use base qw/Scribbler::ActionTile/;

my ($Self, $EditWindow, $OldColor, $NewColor, @CanCall, $SubIndex, %BtnSub);

sub new {
 	my $invocant = shift;
 	my $class = ref($invocant) || $invocant;
 	my $parent = shift;
	my $self = Scribbler::ActionTile::new($class, $parent, @_);
	$self->action(call => '');
	return $self
}

sub editor {
	$Self = shift;
	return undef unless @CanCall = $Self->subroutine->canCall;
	$EditWindow = $Self->_createEditWindow() unless $EditWindow;
	$NewColor = $OldColor = $Self->action('call');
	$SubIndex = (grep {$NewColor eq $CanCall[$_]} (0 .. @CanCall - 1))[0] || 0;
	$NewColor = $CanCall[$SubIndex];
	$Self->_updateWindow();
	return $EditWindow
}

sub _createEditWindow {
	my $self = shift;
	my $scribbler = $self->scribbler;
	my $mw = $scribbler->mainwindow->Toplevel(-title => $scribbler->translate('call', 1), -background => $BG);
	$mw->withdraw;
	$scribbler->windowIcon($mw, 'call_red');
	foreach (qw/call_ okay no/) {
		$BtnSub{$_} = $mw->ToggleButton(
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
				-pressimage => $scribbler->button("multi_$_" . '_press'),
				-offimage => $scribbler->button("multi_$_" . '_release')
			) : (
				-pressimage => $scribbler->button($_ . '_press'),
				-offimage => $scribbler->button($_ . '_release'),
			),
			-command => [\&_evtClickButton, $_]
		)->pack(-side => 'left')
	}
	$scribbler->tooltip($BtnSub{call_}, 'Select subroutine to call.');
	return $mw
}

sub _evtClickButton {
	my $btn = shift;
	my $okay = $btn eq 'okay';
	if ($okay || $btn eq 'no') {
		if ($okay && $NewColor ne $OldColor) {
			$Self->action('call', $NewColor);
			$Self->call($NewColor)
		}
		$Self->{'done'} = $btn
	} elsif ($btn eq 'call_') {
		$SubIndex = ($SubIndex + 1) % scalar(@CanCall);
		$NewColor = $CanCall[$SubIndex];
		$Self->_updateWindow();
	}		
}

sub _updateWindow {
	my $self = shift;
	my $scribbler = $self->scribbler;
	$BtnSub{'call_'}->pressimage($scribbler->button("multi_call_$NewColor\_press"));
	$BtnSub{'call_'}->offimage($scribbler->button("multi_call_$NewColor\_release"))
}

sub icon {
	return 'call_red'
}

1;

