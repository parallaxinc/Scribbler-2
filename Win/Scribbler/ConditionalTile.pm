package Scribbler::ConditionalTile;
use strict;
use Carp qw/cluck confess/;
use Scribbler;
use Scribbler::Constants;
use Scribbler::AtomBlock;
use Tie::IxHash;
use base qw/Scribbler::Tile/;

my @Offsets = ([-15, -6], [2, -5]);

sub new {
 	my $invocant = shift;
 	my $class = ref($invocant) || $invocant;
 	my $parent = shift;
 	return Scribbler::Tile::new($class, $parent, @_);
}

sub code {
	my $self = shift;
	return '' unless $self->subclass =~ m/(if_begin|unless_begin|andif|andunless|else_begin)/;
	my $subclass = $1;
	if ($subclass eq 'if_begin') {
		return 'if (' . $self->_condition
	} elsif ($subclass eq 'unless_begin') {
		return 'ifnot (' . $self->_condition 
	} elsif ($subclass eq 'andif') {
		return ' and ' . $self->_condition
	} elsif ($subclass eq 'andunless') {
		return ' and not(' . $self->_condition . ')'
	}
}

sub _condition {
	my $self = shift;
	my $condition = $self->action('icon');
	my $value = (($self->action('text') || '0') =~ m/(\d+)/)[0];
	if ($condition =~ m/flag_(.+)/) {
		return "Flag_$1"
	} elsif ($condition =~ m/line_([ld])([ld])/) {
		my $cond = $1 eq 'd' ? 'LeftLine == 1' : 'LeftLine == 0';
		$cond .= ' and ' . ($2 eq 'd' ? 'RightLine == 1' : 'RightLine == 0');
		$cond .= " and LineCount => $value" if $value;
		return $cond
	} elsif ($condition eq 'bar_fwd') {
		return "LineCount == $value"
	} elsif ($condition eq 'bar_rev') {
		return "LineCount == " . ($value | 8)
	} elsif ($condition eq 'bar_both') {
		return "LineCount & 7 == $value"
	} elsif ($condition eq 'stall') {
		my $cond = 'Stalled == 1';
		$cond .= "and StallCount => $value" if $value;
		return $cond
	} elsif ($condition =~ m/obstacle_([wr])([wr])/) {
		my $cond = $1 eq 'r' ? 'LeftObstacle == 0' : 'LeftObstacle == 1';
		$cond .= ' and ' . ($2 eq 'r' ? 'RightObstacle == 0' : 'RightObstacle == 1');
		$cond .= " and ObstacleCount => $value" if $value;
		return $cond
	} elsif ($condition =~ m/light_([xld]{3}|min|max|avg)/) {
		my $lights = $1;
		my $cond;
		$value = $value || 1;
		if ($lights eq 'lxx') {
			return "LeftLight => $value"
		} elsif ($lights eq 'xlx') {
			return "CenterLight => $value"
		} elsif ($lights eq 'xxl') {
			return "RightLight => $value"
		}elsif ($lights eq 'min') {
			return "LeftLight <# CenterLight <# RightLight => $value"
		} elsif ($lights eq 'max') {
			return "LeftLight #> CenterLight #> RightLight => $value"
		} elsif ($lights eq 'avg') {
			return "(LeftLight + CenterLight + RightLight) / 3 => $value"
		} elsif ($lights eq 'lld') {
			return "LeftLight - RightLight => $value and CenterLight - RightLight => $value"
		} elsif ($lights eq 'ldl') {
			return "LeftLight - CenterLight => $value and RightLight - CenterLight => $value"
		} elsif ($lights eq 'ldd') {
			return "LeftLight - CenterLight => $value and LeftLight - RightLight => $value"
		} elsif ($lights eq 'dll') {
			return "CenterLight - LeftLight => $value and RightLight - LeftLight => $value"
		} elsif ($lights eq 'ddl') {
			return "RightLight - LeftLight => $value and RightLight - CenterLight => $value"
		} elsif ($lights eq 'dld') {
			return "CenterLight - LeftLight => $value and CenterLight - RightLight => $value"
		}
	} elsif ($condition eq 'coin_heads') {
		my $mask = $self->scribbler->random($value || 1);
		return "CoinFlip & $mask == 0"
	} elsif ($condition eq 'reset') {
		my $parent = $self->parent->parent;
	 	if (ref($parent->parent) eq 'Scribbler::Subroutine' && $parent->subroutine->color eq $ROOT_COLOR && $parent->findMe == 1) {
			return "ResetCount == $value"
		} else {
			return '0'
		} 
	} else {
		return '<condition>'
	}
}	

sub createImage {
	my $self = shift;
	$self->configure(@_) if @_;
 	my $icon = $self->action('icon');
 	my $text = $self->action('text');
 	$text = '' unless defined $text;
 	my $subclass = $self->subclass;
 	my $offsets = $Offsets[($subclass =~ m/and/) || 0];
 	if ($subclass =~ m/if_begin|unless_begin|andif|andunless/) {
		$self->SUPER::createImage(
	 		tile => "cond_$subclass",
	 		$icon ? (icon => [$icon, $XC + $offsets->[0], $YC + $offsets->[1]]) : (),
			$text ne '' ? (text => [$text, $XC - 20, $Y1 - 16]) : (),
	 		ghost => 'YELLOW'
	 	)
	} else {
		$self->SUPER::createImage(tile => '');
	}
 	$self->drawVectors;
}

sub redraw {
	my $self = shift;
	return unless $self->worksheet;
	$self->SUPER::redraw;
	$self->drawVectors;
	return $self->size
}

sub reactivate {
	my $self = shift;
	return 1 unless $self->worksheet;
	my $active = $self->SUPER::reactivate(@_);
	if (my $vectors = $self->image('vectors')) {
		if ($active == 1) {
			$self->configureLines($vectors, 'raise', -fill => $ACTIVE_LINE_COLOR);
		} else {
			$self->configureLines($vectors, 'lower', -fill => $INACTIVE_LINE_COLOR);
		}
	}
	return $active
}

sub drawVectors {
	my $self = shift;
	$self->worksheet and my $conditional = $self->enclosing('Scribbler::ConditionalArray') or return;
	my $subclass = $self->subclass;
	my $active = $self->reactivate;
	my $canvas = $self->canvas;
	my ($x, $y) = $self->location;
	my ($x0, $y0) = $conditional->location;
	my $height = ($conditional->size)[1];
	my @widths = map {$_->width} $conditional->children;
	my @heights = map {$_->height} $conditional->children;
	my $color;
	my $index = $self->parent->findMe;
	if (my $vectors = $self->image('vectors')) {
		$color = $canvas->itemcget($vectors->[0], '-fill');
		$canvas->delete(@$vectors)
	} else {
		$color = $INACTIVE_LINE_COLOR
	}
	if ($subclass =~ m/if_begin|unless_begin/) {
		$self->image->{vectors} = [$self->SUPER::drawVectors(
			[$x + 1 + $TILE_XINDENT, $y + 0.5,
			$x + $widths[$index] + $TILE_XINDENT, $y + 0.5],
			-fill => $color
		)]
	} elsif ($subclass eq 'else_begin') {
			$self->image->{vectors} = [$self->SUPER::drawVectors(
				[$x + $TILE_XINDENT, $y + 0.5,
				$x + 0.5, $y + 0.5,
				$x + 0.5, $y + 1 + $TILE_YINDENT],
				-fill => $color
			)]
	} elsif ($subclass =~ m/if_end|else_end/) {
		$self->image->{vectors} = [$self->SUPER::drawVectors(
			[$x + 0.5, $y + $TILE_YINDENT,
			$x + 0.5, $self->parent ne $conditional->begin ? (
				$y0 + $height - 0.5,
				$x0 + 0.5, $y0 + $height - 0.5, 
				$x0 + 0.5
			) : (), $y0 + $height + $TILE_YINDENT],
			-fill => $color
		)]
	} elsif ($subclass eq 'else_end') {
		$self->image->{vectors} = [$self->SUPER::drawVectors(
			[$x + 0.5, $y + $TILE_YINDENT,
			$x + 0.5, $y0 + $height - 0.5,
			$x0 + 0.5, $y0 + $height - 0.5],
			-fill => $color
		)]
	}
	$self->configureLines($self->image->{vectors}, 'lower') if $color eq $INACTIVE_LINE_COLOR
}

my ($Self, $EditWindow, $CanCond, $SelfEdit, %BtnCond, %Index, $Button, $Text, $Slider, $SliderValue, %SliderValues, $Sensor);
my $Columns = 2;

tie my %Sensors, 'Tie::IxHash', (

	flag => {
		icons => [map {"flag_$_"} @FLAG_COLORS],
		maxvalue => 0,
		text => sub{''},
		tip => 'Flag up',
		slidertip => '',
	},
	
	line => {
		icons => [qw/line_ld line_ll line_dl line_dd/],
		maxvalue => 8,
		onselect => sub{_evtSelectReps('line')},
		onslider => \&_setReps,
		text => \&_defaultText,
		tip => 'Line and barcode sensor', 
		slidertip => 'Set required consecutive observations.',
	},
	
	bar => {
		icons => [qw/bar_fwd bar_rev bar_both/],
		maxvalue => 7,
		onselect => sub{_evtSelectReps('line')},
		text => sub{"=$SliderValue"},
		tip => 'Line and barcode sensor', 
		slidertip => 'Select the barcode to recognize.',
	},
	
	obstacle => {
		icons => [qw/obstacle_wr obstacle_rr obstacle_rw obstacle_ww/],
		maxvalue => 8,
		onselect => sub{_evtSelectReps('obstacle')},
		onslider => \&_setReps,
		text => \&_defaultText,
		tip => 'Obstacle and crash sensors',
		slidertip => 'Set required consecutive observations.',
	},
	
	stall => {
		icons => [qw/stall/],
		maxvalue => 8,
		onselect => sub{_evtSelectReps('obstacle')},
		onslider => \&_setReps,
		text => \&_defaultText,
		tip => 'Obstacle and crash sensors',
		slidertip => 'Set required consecutive observations.',
	},
	
	light => {
		icons => [qw/light_lxx light_xlx light_xxl light_ldd light_dld light_ddl light_lld light_ldl light_dll light_min light_max light_avg/],
		maxvalue => 255,
		onselect => \&_evtSelectLight,
		onslider => \&_evtSlideLight,
		text => sub{"$SliderValue+"},
		tip => 'Light sensors',
		slidertip => 'Set threshold brightness level.',
	},
	
	coin => {
		icons => [qw/coin_heads/],
		maxvalue => 8,
		onselect => sub{_evtSelectReps('coin_heads')},
		onslider => \&_setReps,
		text => \&_defaultText,
		tip => 'Coin flip came up "heads"',
		slidertip => 'Set required consecutive observations.',
	},
	
	reset => {
		icons => [qw/reset/],
		maxvalue => 8,
		onselect => sub{_evtSelectReps('coin_heads')},
		onslider => \&_setReps,
		text => sub{"=$SliderValue"},
		tip => 'Reset button was pressed',
		slidertip => 'Set required consecutive observations.',
	}
	
);

sub _defaultText {
	return $SliderValue > 1 ? "$SliderValue+" : ''
}

tie my %Buttons, 'Tie::IxHash', (
	flag => {sensors => [qw/flag/]},
	line => {sensors => [qw/line bar/]},
	obstacle => {sensors => [qw/obstacle stall/]},
	light => {sensors => [qw/light/]},
	coin => {sensors => [qw/coin reset/]}
);

foreach my $btn (keys %Buttons) {
	$Buttons{$btn}->{icons} = [];
	foreach (@{$Buttons{$btn}->{sensors}}) {
		$Sensors{$_}->{button} = $btn; 
		push @{$Buttons{$btn}->{icons}}, @{$Sensors{$_}->{icons}}
	}
}

sub editor {
	$Self = shift;
	$EditWindow = $Self->_createEditWindow() unless $EditWindow;
	$SelfEdit->subclass($Self->subclass);
	$SelfEdit->action(%{$Self->action});
	my $icon = $Self->action('icon') || 'flag_green';
	$SelfEdit->action(icon => $icon);
	my $sensor = $Self->sensor($icon);
	my $btn = $Sensors{$sensor}->{button};
	$Button = '';
	&{$Sensor->{onselect}}(0) if $Sensor && $Sensor->{onselect};
	$Sensor = '';
	my @icons = @{$Buttons{$btn}->{icons}};
	%Index = map {$_ => 0} keys %Sensors;
	%SliderValues = map {$_ => 0} values %Sensors;
	$SliderValue = $SliderValues{$Sensors{$sensor}} = (($SelfEdit->action('text') || '0') =~ m/(\d+)/)[0] || 0;
	$Index{$btn} = (grep {$icon eq $icons[$_]} (0 .. @icons - 1))[0];
	_redrawButtons(map {[$_ => $Buttons{$_}->{icons}->[$Index{$_}]]} keys %Buttons);
	$BtnCond{$btn}->TurnOff;
	$BtnCond{$btn}->TurnOn;
	$SelfEdit->_updateWindow;
	return $EditWindow
}

sub _createEditWindow {
	my $self = shift;
	my $scribbler = $self->scribbler;
	my $mw = $scribbler->mainwindow->Toplevel(-background => $BG, -title => $scribbler->translate('test a condition', 1));
	$scribbler->windowIcon($mw, 'if_else');
	$mw->withdraw;
	my $frame1 = $mw->Frame(-background => $BG)->pack(-side => 'top', -expand => 1, -fill => 'x');
	my $frame2 = $mw->Frame(-background => $BG)->pack(-side => 'bottom', -padx => 2, -pady => 2, -expand => 1, -fill => 'x');
	my $frame3 = $frame1->Frame(-background => $BG)->pack(-side => 'left', -padx => 2, -pady => 2, -expand => 1, -fill=> 'y');
	my $column = 0;
	my $fraHoriz;
	foreach (keys %Buttons) {
		$fraHoriz = $frame3->Frame(-background => $BG)->pack(-anchor => 'w') if $column++ % $Columns == 0;
		$Index{$_} = 0;
		my $icon = $Buttons{$_}->{icons}->[0];
		my $sensor = $Buttons{$_}->{sensors}->[0];
		$BtnCond{$_} = $fraHoriz->ToggleButton(
			-width => $BTN_SZ,
			-height => $BTN_SZ,
			-ontrigger => 'release',
			-offtrigger => 'press',
			-latching => 1,
			-togglegroup => \%BtnCond,
			-onbackground => $BG,
			-offbackground => $BG,
			-onrelief => 'flat',
			-offrelief => 'flat',
			-pressrelief => 'flat',
			-cursor => 'hand2',
			-borderwidth => 0,
			-index => $_,
			-offimage => $scribbler->button("multi_$icon\_off"),
			-pressimage => $scribbler->button("multi_$icon\_push"),
			-pressonimage => $scribbler->button("multi_$icon\_pushon"),
			-onimage => $scribbler->button("multi_$icon\_on"),
			-command => \&_evtConditionSelect
		)->pack(-side => 'left', -anchor => 'w', -pady => 0, -padx => 0);
		$scribbler->tooltip($BtnCond{$_}, $Sensors{$sensor}->{tip})
	}
	$fraHoriz = $frame3->Frame(-background => $BG)->pack(-anchor => 'w') if $column++ % $Columns == 0;
	
	my $swap = $fraHoriz->ToggleButton(
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
		-pressimage => $scribbler->button('swap_press'),
		-offimage => $scribbler->button('swap_release'),
		-command => \&_evtSwap
	)->pack(-side => 'right', -pady => 0, -padx => 0);
	$scribbler->tooltip($swap, 'Switch TRUE and FALSE directions');
	
	$CanCond = $frame1->Canvas(
		-height=> 140,
		-width => 175,
		-background => 'LIGHTBLUE',
	)->pack(-side => 'right', -expand => 1, -fill => 'y');
	
	$CanCond->createRectangle(
		27, 100, 147, 140,
		-fill => $DARK_SCRIBBLER_BLUE,
		-outline => $DARK_SCRIBBLER_BLUE,
		-width => 8,
		-state => 'hidden',
		-tags => 'light'
	);		
	
	$CanCond->createOval(
		($_ - 1.5) * 40 + 87, 100, ($_ - 0.5) * 40 + 87, 140,
		-fill => 'BLACK',
		-outline => $DARK_SCRIBBLER_BLUE,
		-width => 8,
		-state => 'hidden',
		-tags => ['light', "light_$_"]
	) foreach (0 .. 2);
	
	foreach my $rep (1 .. 8) {
		$CanCond->createImage(
			85 + 8 * $rep, 135 - 8 * $rep,
			-image => $scribbler->icon('line_dl'),
			-tags => [map {"reps_$_"} ($rep .. 8)],
			-state => 'hidden'
		)
	}		
	
	$SelfEdit = Scribbler::ConditionalTile->new('', subclass => 'if_begin', canvas => $CanCond, size => [1,1]);
	$SelfEdit->createImage;
	$SelfEdit->location(0, 0.05);
	$SelfEdit->SUPER::redraw;
	$SelfEdit->SUPER::reactivate(1);
	
	$Slider = $frame2->Scale(
		-background => '#556666',
		-activebackground => '#00EEEE',
		-highlightthickness => 0,
		-troughcolor => $BG,
		-command => \&_evtChangeSlider,
		-from => 1,
		-to => 99,
		-cursor => 'hand2',
		-orient => 'horizontal',
		-relief => 'sunken',
		-width => $SLIDER_WIDTH,
		-sliderlength => $SLIDER_LENGTH,
		-showvalue => 0,
		-variable => \$SliderValue
	)->pack(-side => 'left', -padx => 5, -pady => 2, -expand => 1, -fill => 'x');
	
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
			-cursor => 'hand2',
			-borderwidth => 0,
			-pressimage => $scribbler->button($_ . '_press'),
			-offimage => $scribbler->button($_ . '_release'),
			-command => [\&_evtClickButton, $_]
		)->pack(-side => 'right', -pady => 0, -padx => 0)
	}
	
	return $mw
}

sub _evtConditionSelect {
	my ($on, $btn) = @_;
	return unless $on;
	my $scribbler = $Self->scribbler;
	my @icons = @{$Buttons{$btn}->{icons}};
	if ($btn eq $Button) {
		$Index{$btn} = ($Index{$btn} + 1) % @icons
	} else {
		$Button = $btn
	}
	my $icon = $SelfEdit->action(icon => $icons[$Index{$btn}]);
	_redrawButtons([$btn => $icon]);
	my $sensor = $Sensors{$Self->sensor($icon)};
	if ($sensor ne $Sensor) {
		&{$Sensor->{onselect}}(0) if $Sensor && $Sensor->{onselect};
		$SliderValues{$Sensor} = $SliderValue;
		$Sensor = $sensor;
		if ($Sensor->{maxvalue}) {
			$Slider->configure(-to => $Sensor->{maxvalue}, -state => 'normal');
			$SliderValue = $SliderValues{$Sensor} || 1;
			$scribbler->tooltip($Slider, $Sensor->{slidertip})
		} else {
			$SliderValue = 1;
			$Slider->configure(-state => 'disabled');
			$scribbler->tooltip($Slider, '')
		}
		&{$Sensor->{onselect}}(1) if $Sensor->{onselect}
	}
	_evtChangeSlider();
	$SelfEdit->_updateWindow
}

sub _redrawButtons {
	my $scribbler = $SelfEdit->scribbler;
	foreach (@_) {
		my ($btn, $icon) = @$_;
		my $multi = @{$Buttons{$btn}->{icons}} > 1 ? 'multi_' : '';
		$BtnCond{$btn}->configure(
			-offimage => $scribbler->button("$multi$icon\_off"),
			-pressimage => $scribbler->button("$multi$icon\_push"),
			-pressonimage => $scribbler->button("$multi$icon\_pushon"),
			-onimage => $scribbler->button("$multi$icon\_on")
		);
		$scribbler->tooltip($BtnCond{$btn}, $Sensors{$SelfEdit->sensor($icon)}->{tip})
	}
}

sub _evtSelectLight {
	my $on = shift;
	$CanCond->itemconfigure('light', -state => $on ? 'normal' : 'hidden')
}

sub _evtSelectReps {
	my $on = shift;
	if ($on) {
		$CanCond->itemconfigure('reps_8', -image => $SelfEdit->scribbler->icon($SelfEdit->action('icon')));
		_killReps();
		_setReps();
	} else {
		$CanCond->itemconfigure('reps_8', -state => 'hidden')
	}	
}

sub _evtChangeSlider {
	my $icon = $SelfEdit->action('icon');
	my $sensor = $SelfEdit->sensor($icon);
	$SelfEdit->action(text => &{$Sensors{$sensor}->{text}});
	_killReps();
	&{$Sensor->{onslider}} if $Sensor->{onslider};
	$SelfEdit->_updateWindow
}

sub _setReps {
	$CanCond->itemconfigure("reps_$SliderValue", -state => 'normal') if $SliderValue >= 2
}

sub _killReps {
	$CanCond->itemconfigure('reps_8', -state => 'hidden');
}

sub _evtSlideLight {
	my $type = ($SelfEdit->action('icon') =~ m/_([ldx]{3}|min|max|avg)/)[0];
	$type = 'lll' if $type =~ m/min|max|avg/;
	my ($min, $max);
	if ($type =~ m/d/) {
		$min = sprintf('#%6.6X', int(128 - 127 * sqrt($SliderValue) / 16) * 0x010101);
		$max = sprintf('#%6.6X', int(128 + 127 * sqrt($SliderValue) / 16) * 0x010101);
	} else {
		$max = sprintf('#%6.6X', int(255 * sqrt($SliderValue) / 16) * 0x010101);
	}
	foreach (0 .. 2) {
		my $xld = substr($type, $_, 1);
		$CanCond->itemconfigure("light_$_", -fill =>	$xld eq 'd' ? $min : $xld eq 'x' ? $DARK_SCRIBBLER_BLUE : $max)
	}
}			 

sub _evtClickButton {
	my $btn = shift;
	my $okay = $btn eq 'okay';
	if ($okay || $btn eq 'no') {
		if ($okay) {
			$Self->action(%{$SelfEdit->action});
			$Self->subclass($SelfEdit->subclass);
		}
		$Self->{done} = $btn
	}		
}

sub _evtSwap {
	my $subclass = $SelfEdit->subclass;
	$subclass =~ m/if/ ? $subclass =~ s/if/unless/ : $subclass =~ s/unless/if/;
	$SelfEdit->subclass($subclass);
	$SelfEdit->_updateWindow
}

sub _updateWindow {
	my $self = shift;
	$self->createImage;
	$self->SUPER::reactivate(1);
	$self->SUPER::redraw;
}

sub sensor {
	my $self = shift;
	my $icon = shift;
	return ($icon =~ m/([^_]*)/)[0]
}

1;	

