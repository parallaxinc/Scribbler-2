package Scribbler::MotionTile;
use strict;
use Scribbler::Constants;
use Scribbler::ActionTile;
use Tk;
use Carp qw/cluck/;
use base qw/Scribbler::ActionTile/;

my ($Self, $EditWindow, $CanMove, %BtnMove, %SpnParam);

my $CSEC = 5;
my $MAXCSEC = 500;
my @TimeValues = map sprintf('%4.2f', $_ * $CSEC / 100), (0 .. $MAXCSEC / $CSEC);
my ($TimeIndex, $Turn, $Velocity);

my @CanCall = ('');
my $CallIndex = 0;

my @Types = ('set', 'add', 'mul');
my @TypeChars = ('=', '+', 'x');
my %Type2Char = ((map {$Types[$_], $TypeChars[$_]} (0 .. @Types - 1)), (map {$_, $_} @TypeChars));
my %Char2Type = ((map {$TypeChars[$_], $Types[$_]} (0 .. @TypeChars - 1)), (map {$_, $_} @Types));

my %MoveValues = (
	'set' => [map sprintf('%3.1d', $_ - 100), (0 .. 200)],
	'add' => [map sprintf('%+3.1d', $_ - 100), (0 .. 200)],
	'mul' => [map sprintf('%5.2f', ($_ - 63) * 0.02), (0 .. 126)]
);
$MoveValues{$_} = $MoveValues{$Char2Type{$_}} foreach @TypeChars;
my $Values = $MoveValues{'set'};

my %Icons = (
	'set' => [qw/
		move_rev move_rev_left move_rot_left
		move_rev_right move_stop move_fwd_left
		move_rot_right move_fwd_right move_fwd		
	/],
	
	'add' => [qw/
		move_left_dec_right_dec move_left_dec move_left_dec_right_inc
		move_right_dec move_nop move_right_inc
		move_left_inc_right_dec move_left_inc move_left_inc_right_inc 
	/],

	'mul' => [qw/
		move_left_lo_right_lo move_left_lo move_left_lo_right_hi
		move_right_lo move_nop move_right_hi
		move_left_hi_right_lo move_left_hi move_left_hi_right_hi 
	/]
);
$Icons{$_} = $Icons{$Char2Type{$_}} foreach @TypeChars;
my %IconIndex;
foreach my $type (@TypeChars, @Types) {
	foreach my $index (0 .. 8) {
		$IconIndex{$Icons{$type}[$index]} = $index
	}
}

my @Movements = ([0, 0], [0, 1], [0, 4], [1, 0], [2, 2], [3, 4], [4, 0], [4, 3], [4, 4]);
my %StdMoves = (
	'set' => [50, 67, 100, 133, 150],
	'add' => [90, 100, 100, 100, 110],
	'mul' => [225, 250, 250, 250, 275]
);
$StdMoves{$_} = $StdMoves{$Char2Type{$_}} foreach @TypeChars;
my @NextMove = (1, 2, 5, 0, 8, 4, 3, 6, 7);

my $SelfEdit = Scribbler::MotionTile->new();

sub new {
 	my $invocant = shift;
 	my $class = ref($invocant) || $invocant;
 	my $parent = shift;
	my $self = Scribbler::ActionTile::new($class, $parent, @_);
	$self->action(icon => 'move_fwd', call => '', type => 'set', left => 50, right => 50, timer => 0);
	$self->_tileData;
	return $self
}

sub emitCode {
	my $self = shift;
	my $worksheet = $self->worksheet;
	my ($left, $right, $type, $timer) = map {$self->action($_)} qw/left right type timer/;
	if ($type eq 'set') {
		$timer = int($timer * 1000 + 0.5);
		$left = int($left * 2.56); $right = int($right * 2.56);
		$worksheet->emitCall("MotorSet($left, $right, $timer)");
	} elsif ($type eq 'add') {
		$left = int($left * 2.56); $right = int($right * 2.56);
		$worksheet->emitCall("MotorAdd($left, $right)")
	} elsif ($type eq 'mul') {
		$left = int($left * 1000);
		$right = int($right * 1000);
		$worksheet->emitCall("MotorMul($left, $right)")
	}
}

sub _tileData {
	my $self = shift;
	my $left = $self->action('left');
	my $right = $self->action('right');
	my $type = $Char2Type{$self->action('type')};
	my $text = "$left:$right";
	$text =~ s/ //g;
	$self->action('text' => ($self->action('type') eq 'set' ? '' : $Type2Char{$self->action('type')} . ' ') . $text
		. ($self->action('timer') > 0 ? ' ' . $self->action('timer') . 's' : ''));
	if ($type eq 'mul') {
		$self->action('icon' => $Icons{$type}[(($left <=> 1) + 1) * 3 + ($right <=> 1) + 1])
	} else {
		if ($left * $right > 0) {
			$left = 0 if abs($left) < 0.9 * abs($right);
			$right = 0 if abs($right) < 0.9 * abs($left)
		}
		$self->action('icon' => $Icons{$type}[(($left <=> 0) + 1) * 3 + ($right <=> 0) + 1])
	}
}

sub editor {
	$Self = shift;
	my $scribbler = $Self->scribbler;
	$EditWindow = $Self->_createEditWindow unless $EditWindow;
	$SelfEdit->action(%{$Self->action});
	foreach my $side (qw/left right/) {
		$SelfEdit->action($side => (grep {$SelfEdit->action($side) == $_} @$Values)[0])
	}
	$SelfEdit->{parent} = $Self->parent;
	$SelfEdit->action('type', $Type2Char{$SelfEdit->action('type')});
	@CanCall = ('', $SelfEdit->subroutine->canCall);
	$CallIndex = (grep $CanCall[$_] eq $SelfEdit->action('call'), (0 .. @CanCall - 1))[0] || 0;
	$SelfEdit->_evtTypeSpin(1);
	$SelfEdit->_update;
	return $EditWindow
}

sub _createEditWindow {
	my $self = shift;
	my $scribbler = $self->scribbler;
	my @regions = (
		['left', 0, 0, 40, 200], ['joystick', 40, 0, 160, 200], ['right', 160, 0, 200, 200],
		['stopwatch', 200, 0, 320, 200], ['on/off', 243, 121, 277, 140],
		['timer-', 210, 50, 250, 80], ['timer+', 270, 50, 310, 80]
	);
	my $mw = $scribbler->mainwindow->Toplevel(-title => $scribbler->translate('motion', 1), -background => $BG);
	$scribbler->windowIcon($mw, 'move_fwd');
	$mw->withdraw;
	my $frame = $mw->Frame(-background => $BG)->pack;
	
	my $frame2 = $frame->Frame->pack(-expand => 1, -fill => 'x');
	
	my $scaVel = $frame2->Scale(
		-background => $DARK_SCRIBBLER_BLUE,
		-troughcolor => 'BLACK',
		-activebackground => 'CYAN',
		-width => $SLIDER_WIDTH,
		-sliderlength => $SLIDER_LENGTH,
		-highlightthickness => 0,
		-showvalue => 0,
		-from => 100,
		-to => -100,
		-cursor => 'hand2',
		-variable => \$Velocity,
		-command => [\&_evtMoveSlide, 'velocity']
	)->pack(-side => 'left', -expand => 1, -fill => 'y');
	$scribbler->tooltip($scaVel, 'Overall velocity');
	
	$CanMove = $frame2->Canvas(
		-height=> 200,
		-width => 320,
		-background => 'LIGHTBLUE',
		-highlightthickness => 0
	)->pack(-side => 'top');
	
	$frame2 = $frame->Frame(-background => $DARK_SCRIBBLER_BLUE)->pack(-expand => 1, -fill => 'x');
	$frame2->Frame(
		-background => $DARK_SCRIBBLER_BLUE,
		-width => $SLIDER_WIDTH + 8,
		-highlightthickness => 0,
		-borderwidth => 0
	)->pack(-side => 'left', -anchor => 'w');
	
	my $scaTurn = $frame2->Scale(
		-orient => 'horizontal',
		-background => $DARK_SCRIBBLER_BLUE,
		-troughcolor => 'BLACK',
		-activebackground => 'CYAN',
		-width => $SLIDER_WIDTH,
		-sliderlength => $SLIDER_LENGTH,
		-highlightthickness => 0,
		-showvalue => 0,
		-length => 200,
		-from => -100,
		-to => 100,
		-cursor => 'hand2',
		-variable => \$Turn,
		-command => [\&_evtMoveSlide, 'turn']
	)->pack(-side => 'left', -anchor => 'w');
	$scribbler->tooltip($scaTurn, 'Turning rate');
	
	my $scaTime = $frame2->Scale(
		-orient => 'horizontal',
		-background => $DARK_SCRIBBLER_BLUE,
		-troughcolor => 'BLACK',
		-activebackground => 'CYAN',
		-width => $SLIDER_WIDTH,
		-sliderlength => $SLIDER_LENGTH,
		-highlightthickness => 0,
		-showvalue => 0,
		-from => 0,
		-to => 100,
		-cursor => 'hand2',
		-command => \&_evtTimeSlide,
		-variable => \$TimeIndex
	)->pack(-side => 'left', -anchor => 'w', -expand => 1, -fill => 'x');
	$scribbler->tooltip($scaTime, 'Time interval');
	
	$CanMove->createImage(0, 0, -image => $scribbler->icon('lg_scribbler'), -anchor => 'nw');
	foreach my $side (qw/left right/) {
		$CanMove->createPolygon(_moveArrow($side, 0, abs($MoveValues{'set'}[0])),
			-fill => $side eq 'left' ? 'RED' : 'GREEN',
			-outline => 'BLACK', -width => 2, -tags => [$side, 'set', 'add', 'arrow']
		);
		foreach my $dir (qw/top bottom/) {
			$CanMove->createPolygon(_moveArrow("$side\_$dir", 0, abs($MoveValues{'mul'}[0])),
				-fill => $side eq 'left' ? 'RED' : 'GREEN',
				-outline => 'BLACK', -width => 2, -tags => ["$side\_$dir", 'mul', 'arrow'],
				-state => 'hidden'
			)
		}
	}
	$CanMove->createLine(100, 100, 100, 100, -width => 20, -fill => 'BLACK', -capstyle => 'round', -tags => 'shaft');
	$CanMove->createImage(100, 100, -image => $scribbler->icon('joystick'), -tags => 'joystick');
	$CanMove->CanvasBind('<B1-Motion>' => [\&_evtMoveCanvas, Ev('x'), Ev('y')]);
	$CanMove->createRectangle(220, 75, 300, 125, -fill => '#AAAAAA');
	my @LCD;
	foreach (0 .. 2) {
		$LCD[$_] = $CanMove->createImage($_ * 18 + 240 + ($_ > 0) * 4, 100, -image => $scribbler->lcd(0), tags => "lcd_$_")
	}
	$CanMove->createRectangle(220, 75, 300, 125, -fill => '#555555', tags => 'lcd_off');
	foreach (0 .. 2) {
		$CanMove->createImage($_ * 18 + 240 + ($_ > 0) * 4, 100, -image => $scribbler->lcd('off'), -tags => 'lcd_off')
	}
	$CanMove->createImage(260, 100, -image => $scribbler->icon('stopwatch'));
	$CanMove->bind(
		$CanMove->createRectangle(
			@{$_}[1 .. 4], -width => 0, -fill => 'WHITE', -stipple => 'transparent', -tags => 'clickregion'
		), 
		'<Button-1>' => [\&_evtClickCanvas, $_->[0]]
	) foreach @regions;
	$frame = $mw->Frame(-background => $BG)->pack(-fill => 'x');
	foreach (qw/move_fwd call_ no okay/) {
		$BtnMove{$_} = $frame->ToggleButton(
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
				-pressimage => $scribbler->button("multi_$_" . '_push'),
				-offimage => $scribbler->button("multi_$_" . '_off')
			) : $_ eq 'move_fwd' ? (
				-pressimage => $scribbler->button("multi_$_" . '_press'),
				-offimage => $scribbler->button("multi_$_" . '_release'),
			) : (
				-pressimage => $scribbler->button($_ . '_press'),
				-offimage => $scribbler->button($_ . '_release'),
			),
			-command => [\&_evtClickButton, $_]
		)->pack($_ =~/okay|no/ ? (-side => 'right', -anchor => 'e') : (-side => 'left', -anchor => 'w'), -pady => 2, -padx => 2)
	}
	$scribbler->tooltip($BtnMove{move_fwd}, 'Quick select motion.');
	$scribbler->tooltip($BtnMove{call_}, 'Select subroutine to call.');
	my $frame1 = $frame->Frame(-background => $BG)->pack(-pady => 2);
	$SpnParam{$_} = $frame1->Spinbox(
		-readonlybackground => 'BLACK', -foreground => $_ eq 'left' ? 'RED' : 'GREEN',
		-selectbackground => 'BLACK', -selectforeground => $_ eq 'left' ? 'RED' : 'GREEN',
		-takefocus => 0, -state => 'readonly', -buttonbackground => '#404040',
		-width => 4, -values => [@{$Values}],
		-textvariable => \$SelfEdit->{action}->{$_}, -justify => 'right',
		-command => [\&_evtMoveSpin, $_],
		-font => $scribbler->font('tilefont'), -repeatinterval => 25
	)->pack(-side => $_) foreach qw/left right/;
	$frame1->Label(-text => ' : ', -foreground => 'WHITE', -background => $BG, -font => $scribbler->font('tilefont'))->pack(-side => 'left');
	$frame1 = $frame->Frame(-background => $BG)->pack(-pady => 3);
	$SpnParam{'type'} = $frame1->Spinbox(
		-readonlybackground => 'BLACK', -foreground => 'cyan',
		-selectbackground => 'BLACK', -selectforeground => 'cyan',
		-takefocus => 0, -state => 'readonly', -buttonbackground => '#404040',
		-width => 3, -values => [@TypeChars],
		-textvariable => \$SelfEdit->{action}->{type}, -justify => 'center',
		-command => sub {$SelfEdit->_evtTypeSpin},
		-font => $scribbler->font('tilefont')
	)->pack(-side => 'left');
	$frame1->Label(-text => ' T=', -foreground => 'WHITE', -background => $BG, -font => $scribbler->font('tilefont'))->pack(-side => 'left');
	$SpnParam{'timer'} = $frame1->Spinbox(
		-readonlybackground => 'BLACK', -foreground => 'YELLOW',
		-selectbackground => 'BLACK', -selectforeground => 'YELLOW',
		-takefocus => 0, -state => 'readonly', -buttonbackground => '#404040',
		-width => 4, -values => [@TimeValues],
		-textvariable => \$SelfEdit->{action}->{timer}, -justify => 'right',
		-command => \&_evtTimeSpin,
		-font => $scribbler->font('tilefont')
	)->pack(-side => 'right');
	return $mw
}

sub _evtTypeSpin {
	my $self = shift;
	my $exclude = shift;
	my $type = $Char2Type{$self->action('type')};
	_setWatch(0) if $type ne 'set' && $self->action('timer') > 0;
	$Values = $MoveValues{$type};
	unless ($exclude) {
		foreach (qw/left right/) {
			$SpnParam{$_}->configure(-values => [@{$Values}]);
			$self->action($_ => $Values->[@{$Values} / 2])
		}
	}
	$CanMove->itemconfigure('arrow', -state => 'hidden');
	$CanMove->itemconfigure($type, -state => 'normal');
	$self->_update
}

sub _evtMoveSpin {
	my $side = shift;
	$SelfEdit->{'clicked'} = $side;
	_evtMoveCanvas($CanMove, $side eq 'left' ? 0 : 200, 100 + 100 * $SelfEdit->action($side) / $Values->[0]);
	$SelfEdit->_update('MoveSpin');
}

sub _evtMoveSlide {
	my $which = shift;
	$SelfEdit->{clicked} = 'slide';
	if ($which eq 'velocity') {
		my $av = abs($Velocity);
		$Turn = 100 - $av if $Turn > 100 - $av;
		$Turn = $av - 100 if $Turn < $av - 100
	} else {
		my $at = abs($Turn);
		$Velocity = 100 - $at if $Velocity > 100 - $at;
		$Velocity = $at - 100 if $Velocity < $at - 100
	}
	_evtMoveCanvas($CanMove, $Turn / 2 + 100, 100 - $Velocity / 2);
}

sub _evtTimeSpin {
	my ($timer, $dir) = @_;
	$TimeIndex = _timeIndex($timer);
	#_evtClickCanvas(undef, 'on/off') if $timeindex == 0 && $dir eq 'down' || $timeindex == 1 && $dir eq 'up';
	_setWatch($TimeIndex)
}

sub _evtTimeSlide {
	_setWatch($TimeIndex)
}

sub _update {
	my $self = shift;
	my $scribbler = $self->scribbler;
	$self->_tileData;
	my $exclude = @_ ? shift : '';
	unless ($exclude =~ /MoveSpin/) {_evtMoveSpin($_) foreach qw/left right/}
	unless ($exclude =~ /SetWatch/) {_setWatch(_timeIndex($SelfEdit->action('timer')))}
	$BtnMove{'move_fwd'}->pressimage($scribbler->button('multi_' . $self->action('icon') . '_press'));
	$BtnMove{'move_fwd'}->offimage($scribbler->button('multi_' . $self->action('icon') . '_release'));
	$BtnMove{'call_'}->pressimage($scribbler->button('multi_call_' . $self->action('call') . ($CallIndex ? '_pushon' : '_push')));
	$BtnMove{'call_'}->offimage($scribbler->button('multi_call_' . $self->action('call') . ($CallIndex ? '_on' : '_off')));
}

sub _evtClickCanvas {
	my ($self, $region) = @_;
	$SelfEdit->{clicked} = $region;
	$TimeIndex = _timeIndex($SelfEdit->action('timer'));
	if ($region eq 'on/off') {
		_setWatch($TimeIndex ? 0 : 1)
	} elsif ($region eq 'timer+') {
		_setWatch($TimeIndex + 1) if $TimeIndex > 0 && $TimeIndex < @TimeValues - 1
	} elsif ($region eq 'timer-') {
		_setWatch($TimeIndex - 1) if $TimeIndex > 1
	}
}

sub _setWatch {
	my $scribbler = $Self->scribbler;
	$TimeIndex = shift;
	if ($Char2Type{$SelfEdit->action('type')} ne 'set' && $TimeIndex) {
		$SelfEdit->action('type' => $Type2Char{'set'});
		$SelfEdit->_evtTypeSpin
	}
	$SelfEdit->action('timer' => $TimeValues[$TimeIndex]);
	$CanMove->itemconfigure('lcd_off', -state => $TimeIndex ? 'hidden' : 'normal');
	my $timer = sprintf('%3.3d', int($TimeValues[$TimeIndex] * 100 + 0.5));
	$CanMove->itemconfigure("lcd_$_", -image => $scribbler->lcd(substr($timer, $_, 1))) foreach (0 .. 2)
}

sub _timeIndex {
	my $timer = shift;
	return int($timer	/ $TimeValues[1] + 0.5)
}

sub _evtMoveCanvas {
	my ($canvas, $x, $y) = @_;
	my $clicked = $SelfEdit->{clicked};
	my $type = $Char2Type{$SelfEdit->action('type')};
	my $maxindex = @{$Values} - 1;
	my $fullscale = abs($Values->[0]);
	if ($clicked =~ /joystick|slide|left|right/) {
		($x, $y) = ($x - 100, 100 - $y);
		if ($clicked =~ m/joystick|slide/) {
			my $s = (abs($x) + abs($y)) / 50;
			($x, $y) = ($x / $s, $y / $s) if $s > 1;
			$SelfEdit->action(
				'left' => $Values->[int($maxindex * (($y + $x) / 100 + 0.5) + 0.5)], 
				'right' => $Values->[int($maxindex * (($y - $x) / 100 + 0.5) + 0.5)]
			)
		} elsif ($clicked =~ m/left|right/) {
			$y = -100 if $y < -100; $y = 100 if $y > 100;
			$SelfEdit->action($clicked => $Values->[int($maxindex * ($y / 200 + 0.5) + 0.5)]);
			$x = ($SelfEdit->action('left') - $SelfEdit->action('right')) * 100 / (4 * $fullscale);
			$y = ($SelfEdit->action('left') + $SelfEdit->action('right')) * 100 / (4 * $fullscale)
		}
		($Turn, $Velocity) = ($x * 2, $y * 2) unless $clicked eq 'slide'; 
		$canvas->coords('shaft', 100, 100, $x + 100, 100 - $y);
		$canvas->coords('joystick', $x + 100, 100 - $y);
		if ($type eq 'mul') {
			foreach my $side (qw/left right/) {
				foreach my $dir (qw/top bottom/) {
					$canvas->coords("$side\_$dir", _moveArrow("$side\_$dir", $SelfEdit->action($side), $fullscale))
				}
			}
		} else {
			$canvas->coords($_, _moveArrow($_, $SelfEdit->action($_), $fullscale)) foreach qw/left right/
		}
		$SelfEdit->_update('MoveSpin SetWatch');
	} elsif ($clicked eq 'stopwatch' && $SelfEdit->action('timer') > 0) {
		$TimeIndex = int(((100 - $y) * 1.1 + 100) * @TimeValues / 200);
		_setWatch($TimeIndex) if $TimeIndex > 0 && $TimeIndex < @TimeValues
	}
}

sub _evtClickButton {
	my $btn = shift;
	if ($btn eq 'okay' || $btn eq 'no') {
		if ($btn eq 'okay') {
			$SelfEdit->action('type', $Char2Type{$SelfEdit->action('type')});
			$Self->action(%{$SelfEdit->action});
			$Self->_tileData;
		}
		$Self->{'done'} = $btn
	} elsif ($btn eq 'move_fwd') {
		my $type = $SelfEdit->action('type');
		my $index = $NextMove[$IconIndex{$SelfEdit->action('icon')}];
		$SelfEdit->action(
			'left' =>$Values->[$StdMoves{$type}[$Movements[$index][0]]],
			'right' => $Values->[$StdMoves{$type}[$Movements[$index][1]]]
		);
		$SelfEdit->_update
	} elsif ($btn eq 'call_') {
		$CallIndex = ($CallIndex + 1) % scalar(@CanCall);
		$SelfEdit->action('call', $CanCall[$CallIndex]);
		$SelfEdit->_update('MoveSpin SetWatch')
	}		
}

sub _moveArrow {
	my ($side, $value, $fullscale) = @_;
	my $xc = $side =~ m/left/ ? 20 : 180;
	if ($side =~ /.*_(.*)/) {
		if ($1 eq 'top') {
			map {$xc + (-8, -8, -16, -2, 12, 6, 6)[$_], 1 + 100 / $fullscale * ($fullscale - 1 - ($value - 1) * (0, .5, .5, 1, .5, .5, 0)[$_])} (0 .. 6)
		} else {
			map {$xc + (-4, -4, -12,  2, 16, 8, 8)[$_], 1 + 100 / $fullscale * ($fullscale + 1 + ($value - 1) * (0, .5, .5, 1, .5, .5, 0)[$_])} (0 .. 6)
		}
	} else {
		map {$xc + (-8, -8, -16, 0, 16, 8, 8)[$_], 1 + 100 * (1 - $value / $fullscale * (0, .5, .5, 1, .5, .5, 0)[$_])} (0 .. 6)
	}
}	

1;
