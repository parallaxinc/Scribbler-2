package Scribbler::FlagActionTile;
use strict;
use Carp qw/cluck/;
use Scribbler;
use Scribbler::Constants;
use Scribbler::ActionTile;
use base qw/Scribbler::ActionTile/;

my ($Self, @CanCall, $CallIndex, $EditWindow, %BtnAction, $FlagIndex);

my @Flags = map {("flag_$_\_raise", "flag_$_\_lower")} @FLAG_COLORS;
my $DefaultAction = 'flag_green_raise';

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $parent = shift;
	my $self = Scribbler::ActionTile::new($class, $parent, @_);
	$self->action(icon => $DefaultAction, call => '');
	return $self
}

sub emitCode {
	my $self = shift;
	my ($color, $action) = ($self->action('icon') =~ m/flag_([^_]+)_([^_]+)/);
	$self->worksheet->appendCode("Flag_$color := " . ($action eq 'raise' ? 'true' : 'false'))
}

sub editor {
	$Self = shift;
	$EditWindow = $Self->_createEditWindow() unless $EditWindow;
	@CanCall = ('', $Self->subroutine->canCall);
	$CallIndex = (grep $CanCall[$_] eq $Self->action('call'), (0 .. @CanCall - 1))[0] || 0;
	my $icon = $Self->action('icon');
	$FlagIndex = (grep $Flags[$_] eq $icon, (0 .. @CanCall - 1))[0] || 0;
	_updateWindow();
	return $EditWindow
}

sub _createEditWindow {
	my $self = shift;
	my $scribbler = $self->scribbler;
	my $mw = $scribbler->mainwindow->Toplevel(-title => $scribbler->translate('raise or lower a flag', 1), -background => $BG);
	$scribbler->windowIcon($mw, 'flag_green_raise');
	$mw->withdraw;
	foreach ($DefaultAction, qw/call_ okay no/) {
		$BtnAction{$_} = $mw->ToggleButton(
			-width => $BTN_SZ,
			-height => $BTN_SZ,
			-ontrigger => 'release',
			-latching => 0,
			-onrelief => 'flat',
			-offrelief => 'flat',
			-pressrelief => 'flat',
			-cursor => 'hand2',
			-onbackground => $BG,
			-offbackground => $BG,
			-borderwidth => 0,
			$_ eq 'call_' ? (
				-pressonimage => $scribbler->button("multi_$_" . '_pushon'),
				-pressimage => $scribbler->button("multi_$_" . '_push'),
				-offimage => $scribbler->button("multi_$_" . '_off')
			) : $_ eq $DefaultAction ? (
				-pressimage => $scribbler->button("multi_$_" . '_press'),
				-offimage => $scribbler->button("multi_$_" . '_release'),
			) : (
				-pressimage => $scribbler->button($_ . '_press'),
				-offimage => $scribbler->button($_ . '_release'),
			),
			-command => [\&_evtClickButton, $_]
		)->pack(-side => 'left', -pady => 2, -padx => 2)
	}
	$scribbler->tooltip($BtnAction{call_}, 'Select subroutine to call.');
	$scribbler->tooltip($BtnAction{$DefaultAction}, 'Select flag and action.');
	return $mw
}

sub _updateWindow {
	my $scribbler = $Self->scribbler;
	$BtnAction{$DefaultAction}->configure(
		-pressimage => $scribbler->button("multi_$Flags[$FlagIndex]" . '_press'),
		-offimage => $scribbler->button("multi_$Flags[$FlagIndex]" . '_release')
	);
	$BtnAction{call_}->configure(
		-pressimage => $scribbler->button($CallIndex ? "multi_call_$CanCall[$CallIndex]_pushon" : "multi_call_$CanCall[$CallIndex]_push"),
		-offimage => $scribbler->button($CallIndex ? "multi_call_$CanCall[$CallIndex]_on" : "multi_call_$CanCall[$CallIndex]_off")
	)
}

sub _evtClickButton {
	my $btn = shift;
	my $okay = $btn eq 'okay';
	if ($okay || $btn eq 'no') {
		$Self->worksheet->selectRemoveAll;
		$Self->action(icon => $Flags[$FlagIndex], call => $CanCall[$CallIndex]) if $okay;
		$Self->{'done'} = $btn
	}	elsif ($btn eq $DefaultAction) {
		$FlagIndex = ($FlagIndex + 1) % @Flags
	} else {
		$CallIndex = ($CallIndex + 1) % @CanCall
	}
	_updateWindow()
}

1;

