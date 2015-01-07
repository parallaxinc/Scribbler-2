#############################################################################
#                                                                           #
# togglebutton.pm  Perl/Tk widget to implement latching pushbuttons.        #
#                                                                           #
# File should be installed in <main perl directory>/site/lib/Tk             #
#                                                                           #
# Copyright (C) 2000  Bueno Systems, Inc.                                   #
#                                                                           #
# Contact: Phil Pilgrim: phil@buenosystems.com                              #
#                                                                           #
# This program is free software; you can redistribute it and/or modify      #
# it under the terms of the GNU General Public License as published by      #
# the Free Software Foundation; either version 2 of the License, or         #
# (at your option) any later version.                                       #
#                                                                           #
# This program is distributed in the hope that it will be useful,           #
# but WITHOUT ANY WARRANTY; without even the implied warranty of            #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             #
# GNU General Public License for more details.                              #
#                                                                           #
# You should have received a copy of the GNU General Public License         #
# along with this program; if not, write to the Free Software               #
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA #
#                                                                           #
#############################################################################

package Tk::ToggleButton;

use strict;
use Carp;

use vars qw($VERSION);
$VERSION = '0.002';

use constant DEFAULT_FG => 'BLACK';
use constant DEFAULT_BG => 'SystemButtonFace';

my %OnIndex;

my %Default = (

	-enabled            => 1,           -latching           => 0,
	-on                 => 0,           -alt                => 0,

	-offforeground      => DEFAULT_FG,  -offbackground      => DEFAULT_BG,
	-onforeground       => undef,       -onbackground       => undef,
	-altforeground      => undef,       -altbackground      => undef,
	-onaltforeground    => undef,       -onaltbackground    => undef,
	-activeforeground   => undef,       -activebackground   => undef,
	-disabledforeground => undef,       -disabledbackground => undef,
	
	-offbitmap          => undef,       -onbitmap           => undef,
	-pressbitmap				=> undef,       -pressonbitmap      => undef,
	-offimage           => undef,       -onimage            => undef,
	-pressimage					=> undef,       -pressonimage       => undef,

	-offrelief          => 'raised',    -onrelief           => 'groove',
	-pressrelief        => 'sunken',    -activerelief       => undef
	
);

my @specs = (
	-foreground          => ['SELF', '', '', DEFAULT_FG],
	-background          => ['SELF', '', '', DEFAULT_BG],
	-relief              => ['SELF', '', '', 'raised'],
	-highlightcolor      => ['SELF', '', '', undef],
	-highlightthickness  => ['SELF', '', '', 0],
	-highlightbackground => ['SELF', '', '', undef],
	-takefocus           => ['SELF', '', '', undef],
	
	-command             => ['PASSIVE', '', '', undef],
	-index               => ['PASSIVE', '', '', undef],
	-indexvariable       => ['PASSIVE', '', '', undef],
	-offtrigger          => ['PASSIVE', '', '', 'none'],
	-ontrigger           => ['PASSIVE', '', '', 'release'],

	-active              => ['METHOD', 'active', 'Active', 0],
	-pressed             => ['METHOD', 'pressed', 'Pressed', 0],

	-enabled             => ['METHOD', 'enabled', 'Enabled', 1],
	-latching            => ['METHOD', 'latching', 'Latching', 0],
	-on                  => ['METHOD', 'on', 'On', 0],
	-alt                 => ['METHOD', 'alt', 'Alt', 0],
	
	-onindex             => ['METHOD', 'onindex', 'Onindex', undef]
);
	
foreach (keys %Default) {
	my $attr1 = $_;
	my $attr2 = substr($attr1, 1);
	my $attr3 = ucfirst($attr2);
	push @specs, $attr1, ['METHOD', $attr2, $attr3, $Default{$_}]
}

require Tk::Label;
require Tk::Derived;

use base  qw(Tk::Derived Tk::Label);

Construct Tk::Widget 'ToggleButton';

sub ClassInit {
 my ($class,$mw) = @_;
 $mw->bind($class, '<Button-1>', 'ButtonDown');
 $mw->bind($class, '<ButtonRelease-1>', 'ButtonUp');
 $mw->bind($class, '<KeyPress-space>', 'ButtonDown');
 $mw->bind($class, '<KeyRelease-space>', 'ButtonUp');
 $mw->bind($class, '<KeyPress-Return>', 'ButtonDown');
 $mw->bind($class, '<KeyRelease-Return>', 'ButtonUp');
 $mw->bind($class, '<Enter>', 'Activate');
 $mw->bind($class, '<Leave>', 'Deactivate');
 $class->SUPER::ClassInit($mw);
 return $class;
}

sub InitObject {
	my ($cw,$args) = @_;
	my $cfg = $cw->{'Configure'};
	
	delete $args->{'-relief'} and confess("Can't set -relief during new()");
	delete $args->{'-background'} and confess("Can't set -background during new()");
	delete $args->{'-foreground'} and confess("Can't set -foreground during new()");
	
	foreach (keys %Default) {$cw->{'Configure'}->{$_} = ($args->{$_} or $Default{$_})}
	
	$args->{'-background'} = CurrentBackground($cw);
	$args->{'-foreground'} = CurrentForeground($cw);
	$args->{'-relief'} = CurrentRelief($cw);
	$args->{'-bitmap'} = CurrentBitmap($cw);
	$args->{'-image'} = CurrentImage($cw);
	
	if (my $Group = delete $args->{'-togglegroup'}) {
		$cw->{'Configure'}->{'-togglegroup'} = $Group;
		if ($cw->{'Configure'}->{'-on'}) {
			if (my $on = $OnIndex{$Group}) {
				$on->configure(-on => 0)
			}
			$OnIndex{$Group} = $cw
		}
		$OnIndex{$Group} = '' unless exists $OnIndex{$Group}
	}

	$cw->ConfigSpecs(@specs);

	$cw->SUPER::InitObject($args);
}

sub ButtonDown {
	my $w = shift;
	my $cfg = $w->{'Configure'};
	if ($cfg->{'-enabled'}) {
		$cfg->{'-pressed'} = ($cfg->{'-on'} || 0) + 1;
		if ($cfg->{'-latching'}) {
			if ($cfg->{'-ontrigger'} eq 'press' and not $cfg->{'-on'}) {
				TurnOn($w);
				$cfg->{'-latched'} = 1
			} elsif ($cfg->{'-offtrigger'} eq 'press' and $cfg->{'-on'}) {
				TurnOff($w);
				$cfg->{'-latched'} = 1
			}
		} else {
			TurnOn($w) if $cfg->{'-ontrigger'} eq 'press';
			TurnOff($w) if $cfg->{'-offtrigger'} eq 'press';
		}
		Redraw($w)
	}
}

sub ButtonUp {
	my $w = shift;
	my $cfg = $w->{'Configure'};
	$cfg->{'-pressed'} = 0;
	if ($cfg->{'-latching'}) {
		if ($cfg->{'-ontrigger'} eq 'release' and not $cfg->{'-on'}) {
			TurnOn($w);
		} elsif ($cfg->{'-offtrigger'} eq 'release' and $cfg->{'-on'} and not $cfg->{'-latched'}) {
			TurnOff($w);
		}
		$cfg->{'-latched'} = 0
	} else {
		TurnOn($w) if $cfg->{'-ontrigger'} eq 'release';
		TurnOff($w) if $cfg->{'-offtrigger'} eq 'release';
		$cfg->{'-on'} = 0
	}
	Redraw($w)
}

sub GroupConfigure {
	my ($w, @config) = @_;
	my $cfg = $w->{'Configure'};
	my $group = $cfg->{'-togglegroup'};
	if (ref $group eq 'ARRAY') {
		foreach (@$group) {
			$_->configure(@config)
		}
		@$group
	} elsif (ref $group eq 'HASH') {
		foreach (values %$group) {
			$_->configure(@config)
		}
		values %$group
	} else {
		undef
	}
}

sub TurnOn {
	SetOn(shift, 1)
}

sub TurnOff {
	SetOn(shift, 0)
}

sub SetOn {
	my ($w, $new) = @_;
	$new = ($new ? 1 : 0);
	$w->configure(-on => $new) unless $w->{'Configure'}->{'-on'} == $new;
	$new
}

sub ShowOn {
	my ($w, $new) = @_;
	my $cfg = $w->{'Configure'};
	if (defined $new) {
		$new = ($new ? 1: 0);
		if ($new != $cfg->{'-on'}) {
			$cfg->{'-on'} = $new;
			if (my $ToggleGroup = $cfg->{'-togglegroup'}) {
				my $OnButton = $OnIndex{$ToggleGroup};
				if ($new) {
					if ($OnButton) {
						ShowOn($OnButton, 0) if $OnButton ne $w
					}
					$OnIndex{$ToggleGroup} = $w;
				} elsif ($OnButton) {
					$OnIndex{$ToggleGroup} = '' if $OnButton eq $w
				}
			}
			Redraw($w);
		}
	}
	$cfg->{'-on'}
}

sub ShowAlt {
	my ($w, $new) = @_;
	my $cfg = $w->{'Configure'};
	if (defined $new) {
		$new = ($new ? 1 : 0);
		$cfg->{'-alt'} = $new;
		Redraw($w)
	}
	$cfg->{'-alt'}
}

sub Activate {
	my $w = shift;
	if ($w->cget('-enabled')) {
		$w->configure(-active => 1);
	}
}

sub Deactivate {
	my $w = shift;
	if ($w->cget('-enabled')) {
		$w->configure(-active => 0);
	}
}

sub Redraw{
	my $w = shift;
	$w->configure(-background => CurrentBackground($w));
	$w->configure(-foreground => CurrentForeground($w));
	$w->configure(-relief => CurrentRelief($w));
	$w->configure(-bitmap => CurrentBitmap($w));
	$w->configure(-image => CurrentImage($w));
}	

sub CurrentBackground {
	my $w = shift;
	my $bg;
	my $cfg = $w->{'Configure'};
	if ($cfg->{'-on'}) {
		if ($cfg->{'-alt'}) {
			$bg = ($cfg->{'-onaltbackground'} or $cfg->{'-onbackground'} or $cfg->{'-altbackground'} or $cfg->{'-offbackground'} or DEFAULT_BG)
		} else {
			$bg = ($cfg->{'-onbackground'} or $cfg->{'-offbackground'} or DEFAULT_BG)
		}
	} else {
		if ($cfg->{'-alt'}) {
			$bg = ($cfg->{'-altbackground'} or $cfg->{'-offbackground'} or DEFAULT_BG)
		} else {
			$bg = ($cfg->{'-offbackground'} or DEFAULT_BG)
		}
	}
	if ($cfg->{'-on'} and $cfg->{'-offtrigger'} eq 'none') {
		$bg
	} else {
		if (not $cfg->{'-enabled'}) {
			TransformColor($w, $bg, $cfg->{'-disabledbackground'})
		} elsif ($w->cget('-active')) {
			TransformColor($w, $bg, $cfg->{'-activebackground'})
		} else {
			$bg
		}
	}
}

sub CurrentForeground {
	my $w = shift;
	my $fg;
	my $cfg = $w->{'Configure'};
	if ($cfg->{'-on'}) {
		if ($cfg->{'-alt'}) {
			$fg = ($cfg->{'-onaltforeground'} or $cfg->{'-onforeground'} or $cfg->{'-altforeground'} or $cfg->{'-offforeground'} or DEFAULT_FG)
		} else {
			$fg = ($cfg->{'-onforeground'} or $cfg->{'-offforeground'} or DEFAULT_FG)
		}
	} else {
		if ($cfg->{'-alt'}) {
			$fg = ($cfg->{'-altforeground'} or $cfg->{'-offforeground'} or DEFAULT_FG)
		} else {
			$fg = ($cfg->{'-offforeground'} or DEFAULT_FG)
		}
	}
	if ($cfg->{'-on'} and $cfg->{'-offtrigger'} eq 'none') {
		$fg
	} else {
		if (not $cfg->{'-enabled'}) {
			TransformColor($w, $fg, $cfg->{'-disabledforeground'})
		} elsif ($cfg->{'-active'}) {
			TransformColor($w, $fg, $cfg->{'-activeforeground'})
		} else {
			$fg
		}
	}
}

sub CurrentRelief {
	my $w = shift;
	my $cfg = $w->{'Configure'};
	if ($cfg->{'-pressed'}) {
		$cfg->{'-pressrelief'}
	} elsif ($cfg->{'-on'}) {
		$cfg->{'-onrelief'}
	} elsif ($cfg->{'-active'}) {
		$cfg->{'-activerelief'} or $cfg->{'-offrelief'}
	} else {
		$cfg->{'-offrelief'}
	}
}

sub CurrentBitmap {
	my $w = shift;
	my $cfg = $w->{'Configure'};
	if (my $pressed = $cfg->{'-pressed'}) {
		if ($pressed == 2) {
			$cfg->{'-pressonbitmap'} or $cfg->{'-pressbitmap'} or $cfg->{'-bitmap'}
		} else {
			$cfg->{'-pressbitmap'} or $cfg->{'-bitmap'}
		}
	} elsif ($cfg->{'-on'}) {
		$cfg->{'-onbitmap'} or $cfg->{'-bitmap'}
	} else {
		$cfg->{'-offbitmap'} or $cfg->{'-bitmap'}
	}
}

sub CurrentImage {
	my $w = shift;
	my $cfg = $w->{'Configure'};
	if (my $pressed = $cfg->{'-pressed'}) {
		if ($pressed == 2) {
			$cfg->{'-pressonimage'} or $cfg->{'-pressimage'} or $cfg->{'-image'}
		} else {
			$cfg->{'-pressimage'} or $cfg->{'-image'}
		}
	} elsif ($cfg->{'-on'}) {
		$cfg->{'-onimage'} or $cfg->{'-image'}
	} else {
		$cfg->{'-offimage'} or $cfg->{'-image'}
	}
}

sub TransformColor {
	my ($w, $color, $transform) = @_;
	if (not defined $transform) {
		return $color
	} elsif (ref $transform) {
		my @rgb = map {$_ >> 8} $w->rgb($color);
		my @rgbt = map {$_ >> 8} $w->rgb($transform->[0]);
		my $p = $transform->[1];
		foreach my $i (0..2) {
			$rgb[$i] = $rgb[$i] * (1 - $p) + $rgbt[$i] * $p
		}
		return sprintf('#%2.2X%2.2X%2.2X', (@rgb))
	} else {
		return $transform	
	}
}

sub on {
	my ($w, $new) = @_;
	my $cfg = $w->{'Configure'};
	if (defined $new) {
		$new = ($new ? 1: 0);
		$cfg->{'-on'} = $new;
		if (my $ToggleGroup = $cfg->{'-togglegroup'}) {
			my $OnButton = $OnIndex{$ToggleGroup};
			if ($new) {
				if ($OnButton) {
					TurnOff($OnButton) if $OnButton ne $w
				}
				$OnIndex{$ToggleGroup} = $w;
			} elsif ($OnButton) {
				$OnIndex{$ToggleGroup} = '' if $OnButton eq $w
			}
		}
		Redraw($w);
		${$cfg->{'-indexvariable'}} = ($new ? $cfg->{'-index'} : undef) if ref $cfg->{'-indexvariable'};
		if (my $Command = $cfg->{'-command'}) {
			$w->update;
			my @args;
			if (ref $Command eq 'ARRAY') {
				@args = @{$Command};
				$Command = shift @args;
			}
			&$Command(@args, $new, $cfg->{-index})
		}
	}
	$cfg->{'-on'}
}

sub onindex {
	my ($w, $new) = shift;
	my $cfg = $w->{'Configure'};
	if (defined $new) {
		confess("Can't set -onindex using configure")
	}
	if (my $ToggleGroup = $cfg->{'-togglegroup'}) {
		$OnIndex{$ToggleGroup}->{'Configure'}->{'-index'}
	} elsif ($cfg->{'-on'}) {
		$cfg->{'-index'}
	} else {
		undef
	}
}
	
sub enabled { _docfg('-enabled', @_) }

sub latching { _docfg('-latching', @_) }

sub alt { _docfg('-alt', @_) }
	
sub active { _docfg('-active', @_) }

sub pressed { _docfg('-pressed', @_) }
	
sub offbackground { _docfg('-offbackground', @_) }

sub offforeground { _docfg('-offforeground', @_) }

sub onbackground { _docfg('-onbackground', @_) }

sub onforeground { _docfg('-onforeground', @_) }

sub altbackground { _docfg('-altbackground', @_) }

sub altforeground { _docfg('-altforeground', @_) }

sub onaltbackground { _docfg('-onaltbackground', @_) }

sub onaltforeground { _docfg('-onaltforeground', @_) }

sub offrelief { _docfg('-offrelief', @_) }

sub onrelief { _docfg('-onrelief', @_) }

sub offbitmap { _docfg('-offbitmap', @_) }

sub onbitmap { _docfg('-onbitmap', @_) }

sub pressbitmap { _docfg('-pressbitmap', @_) }

sub offimage { _docfg('-offimage', @_) }

sub onimage { _docfg('-onimage', @_) }

sub pressimage { _docfg('-pressimage', @_) }

sub pressonimage { _docfg('-pressonimage', @_) }

sub activerelief { _docfg('-activerelief', @_) }

sub pressrelief { _docfg('-pressrelief', @_) }

sub activebackground { _docfg('-activebackground', @_) }

sub activeforeground { _docfg('-activeforeground', @_) }

sub disabledbackground { _docfg('-disabledbackground', @_) }

sub disabledforeground { _docfg('-disabledforeground', @_) }

sub _docfg {
	my ($attrib, $w, $new) = @_;
	my $cfg = $w->{'Configure'};
	if (defined $new) {
		$cfg->{$attrib} = $new;
		Redraw($w)
	}
	$cfg->{$attrib}
}

1;

__END__





