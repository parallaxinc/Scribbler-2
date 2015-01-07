package Scribbler::SubroutineTile;
use strict;
use Carp;
use Scribbler::Constants;
use Scribbler::Tile;
use Tk;
use Tk::Checkbutton;
use base qw/Scribbler::Tile/;

my ($Self, $EditWindow, $OldColor, $NewColor, @SubCanBe, $SubIndex, %BtnSub);
my ($fraChange, $fraBtns, $lblFrom, $lblTo, $chkChange, $ChangeCalls);

sub new {
 	my $invocant = shift;
 	my $class = ref($invocant) || $invocant;
 	my $parent = shift;
 	my $self = Scribbler::Tile::new($class, $parent, active => 0, @_)
}

sub createImage {
	my $self = shift;
	$self->configure(@_) if @_;
 	my $subclass = $self->subclass;
 	my $color = $self->parent->color;
 	$self->action('icon', "gear_$color");
	$self->SUPER::createImage(
 		tile => $subclass,
 		#icon => [$subclass eq 'sub_begin' ? "gear_$color" : 'return', $XC, 36],
 		#icon => [$subclass eq 'sub_begin' ? ($color eq 'green' ? 'go' : "gear_$color") : ($color eq 'green' ? 'end' : 'return'), $XC, 36],
 		icon => [$subclass eq 'sub_begin' ? "gear_$color" : ($color eq 'green' ? 'end' : 'return'), $XC, 36],
 		ghost => 'RED'
 	)
}

sub editor {
	$Self = shift;
	$EditWindow = $Self->_createEditWindow() unless $EditWindow;
	$ChangeCalls = 0;
	if ($Self->parent->callsFrom) {
		$fraChange->pack(-side => 'top')
	} else {
		$fraChange->packForget
	}
	$NewColor = $OldColor = $Self->parent->color;
	$lblFrom->configure(-image => $Self->scribbler->icon("call_$OldColor"));
	@SubCanBe = $Self->parent->canBe;
	$SubIndex = (grep {$NewColor eq $SubCanBe[$_]} (0 .. @SubCanBe - 1))[0] || 0;
	$NewColor = $SubCanBe[$SubIndex];
	$Self->_updateWindow();
	return $EditWindow
}

sub _createEditWindow {
	my $self = shift;
	my $scribbler = $self->scribbler;
	my $mw = $scribbler->mainwindow->Toplevel(-title => $scribbler->translate('subroutine', 1));
	$mw->withdraw;
	$scribbler->windowIcon($mw, 'gear_red');
	$fraChange = $mw->Frame->pack(-side => 'top');
	$fraBtns = $mw->Frame(-background => $BG)->pack(-side => 'bottom');
	$lblFrom = $fraChange->Label(
		-image => $scribbler->icon('call_red')
	)->pack(-side => 'left', -pady => 2);
	$fraChange->Label(
		-image => $scribbler->icon('to'),
		-width => 20
	)->pack(-side => 'left', -pady => 2);
	$lblTo = $fraChange->Label(
		-image => $scribbler->icon('call_red')
	)->pack(-side => 'left', -pady => 2);
	$fraChange->Label(
		-image => $scribbler->icon('query'),
		-width => 20
	)->pack(-side => 'left', -pady => 2);
	$chkChange = $fraChange->Checkbutton(
		-cursor => 'hand2',
		-variable => \$ChangeCalls
	)->pack(-side => 'left', -pady => 2);
	$scribbler->tooltip($chkChange, 'Check to change all calls to new color.');
	foreach (qw/multi_gear_ okay no/) {
		$BtnSub{$_} = $fraBtns->ToggleButton(
			-width => $BTN_SZ,
			-height => $BTN_SZ,
			-ontrigger => 'release',
			-latching => 0,
			-onrelief => 'flat',
			-offrelief => 'flat',
			-pressrelief => 'flat',
			-onbackground => $BG,
			-offbackground => $BG,
			-cursor => 'hand2',
			-borderwidth => 0,
			-pressimage => $scribbler->button($_ . '_press'),
			-offimage => $scribbler->button($_ . '_release'),
			-command => [\&_evtClickButton, $_]
		)->pack(-side => 'left', -pady => 2, -padx => 2)
	}
	$scribbler->tooltip($BtnSub{multi_gear_}, 'Select new subroutine color.');
	return $mw
}

sub _evtClickButton {
	my $btn = shift;
	my $okay = $btn eq 'okay';
	if ($okay || $btn eq 'no') {
		my $subroutine = $Self->subroutine;
		if ($okay && $NewColor ne $OldColor) {
			if ($ChangeCalls) {
				$Self->worksheet->changeColors($OldColor => $NewColor)
			} elsif ($subroutine->callsFrom) {
				my $sub = $Self->worksheet->subroutine($NewColor);
				if ((my $children = $subroutine->children) > 2) {
					my @guts = $subroutine->adoptSiblings($sub, $subroutine->child(1), $subroutine->child(-2));
					$sub->insertBefore(1, @guts);
					$_->callRestore foreach $sub->offspring
				}
			} else {
				$Self->parent->color($NewColor)
			}
		}
		$Self->{'done'} = $btn
	} elsif ($btn eq 'multi_gear_') {
		$SubIndex = ($SubIndex + 1) % scalar(@SubCanBe);
		$NewColor = $SubCanBe[$SubIndex];
		$Self->_updateWindow();
	}		
}

sub _updateWindow {
	my $self = shift;
	my $scribbler = $self->scribbler;
	$lblTo->configure(-image => $scribbler->icon("call_$NewColor"));
	$chkChange->configure(-state => $OldColor eq $NewColor ? 'disabled' : 'normal');
	$BtnSub{'multi_gear_'}->pressimage($scribbler->button("multi_gear_$NewColor\_press"));
	$BtnSub{'multi_gear_'}->offimage($scribbler->button("multi_gear_$NewColor\_release"))
}

1;
