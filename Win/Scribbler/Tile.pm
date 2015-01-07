package Scribbler::Tile;
use strict;
use base qw/Scribbler::Atom/;
use Carp qw/carp cluck/;
use Scribbler::Constants;

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $parent = shift;
	my $self = Scribbler::Atom::new($class, $parent, @_);
	return $self
}

sub clone {
	my $self = shift;
	my $parent = shift;
	my @args;
	foreach (keys %{$self}) {
		push(@args, $_, $self->{$_}) unless $_ =~ m/image|action|parent|call|selected|location/
	}
	my $clone = $self->new($parent, @args);
	$clone->action(%{$self->action});
	return $clone
}

sub redraw {
	my $self = shift;
	#return unless $self->worksheet;
	$self->createImage unless $self->{image}->{tile};
	my ($x, $y) = $self->location;
	$self->worksheet->grid($x, $y, $self) if $self->worksheet;
	my $canvas = $self->canvas;
	$canvas->coords($self->image('tile'), $self->coords($x, $y));
	$canvas->coords($self->image('shadow'), $self->coords($x + 0.5, $y + 0.5));
	$canvas->lower($self->image('shadow'), $self->image('tile'));
	if ($self->{selected}) {
		$self->{selected} = 0;
		$self->selected(1)
	}
	return $self->size(1, 1);
}

sub reactivate {
	my $self = shift;
	#return 1 unless $self->worksheet;
	my $active = $self->worksheet ? $self->SUPER::reactivate(@_) : shift || 0;
	my $index = int($active);
	my $canvas = $self->canvas;
	my $img = $self->image('active');
	$canvas->dtag($img->[1 - $index], 'full_only');
	$canvas->addtag('full_only', withtag => $img->[$index]);
	$canvas->itemconfigure($img->[$index], -state => 'normal');
	$canvas->itemconfigure($img->[1 - $index], -state => 'hidden');
	return $active;
}

sub reimage {
	my $self = shift;
	if ($self->image) {
		$self->createImage;
		$self->redraw;
		$self->parent->reactivate
	}
}

sub createImage {
	my $self = shift;
	if (@_) {
		$self->deleteImage;
		my $scribbler = $self->scribbler;
		my $wsname = $self->worksheet ? '' . $self->worksheet->id : '<none>';
		my $canvas = $self->canvas;
		my @group;
		my @location = $self->location;
		while (@_) {
			my $item = shift;
			if ($item eq 'tile') {
				my $name = shift;
				my ($imgInactive, $imgActive, $imgShadow);
				if ($name) {
					$imgInactive = $canvas->createImage(
						$XC, $YC,
						-image => $scribbler->tile("$name\_disabled"),
						-tags => [$wsname, 'full_only'],
						-state => 'normal'
					);
					$imgActive = $canvas->createImage(
						$XC, $YC,
						-image => $scribbler->tile("$name"),
						-tags => [$wsname],
						-state => 'hidden'
					);
					$imgShadow = $canvas->createImage(
						$XC, $YC,
						-image => $scribbler->tile("$name\_shadow"),
						-tags => [$wsname, 'shadow'],
						-state => 'hidden'
					)
				} else {
					$imgInactive = $canvas->createImage($XC, $YC, -image => $scribbler->icon('blank'));
					$imgActive = $canvas->createImage($XC, $YC, -image => $scribbler->icon('blank'));
					$imgShadow = $canvas->createImage($XC, $YC, -image => $scribbler->icon('blank'))
				}	
				push @group, $imgInactive, $imgActive;
				$self->{image}->{active} = [$imgInactive, $imgActive];
				$self->{image}->{shadow} = $imgShadow;
			} elsif ($item eq 'icon') {
				my ($name, $x, $y) = @{shift()};
				push @group, $canvas->createImage(
					$x * $FS, $y * $FS,
					-image => $scribbler->icon($name),
					-tags => [$wsname, 'full_only'],
					-state => 'normal'
				);
			} elsif ($item eq 'text') {
				my ($text, $x, $y, $color) = @{shift()};
				$color = 'BLACK' unless $color;
				$text =~ s/-/$MINUS/g;
				push @group, $canvas->createText(
					$x * $FS, $y * $FS,
					-text => $text,
					-font => $scribbler->font('tilefont'),
					-fill => $color,
					-tags => [$wsname, 'full_only']
				)
			} elsif ($item eq 'ghost') {
				push @group, $canvas->createRectangle(
					$X0 + 1, $Y0 + 1 , $X1 - $X0, $Y1 - $Y0,
					-fill => shift,
					-tags => [$wsname, 'zoom_only'],
					-state => 'hidden'
				)
			} elsif ($item eq 'location') {
				@location = @{shift()}
			} else {
				shift;
				carp "Bad image item '$item' in createImage."
			}
		}
		$self->{image}->{tile} = $canvas->createGroup(0, 0, -members => [@group]);
		$self->location(@location)
	}
	return $self->{image}
}

sub deleteImage {
	my $self = shift;
	my $canvas = $self->canvas;
	if (my $image = $self->{image}) {
		my $group = $image->{tile};
		$canvas->delete($canvas->itemcget($group, -members));
		$canvas->delete($group);
		$canvas->delete($image->{shadow});
		$canvas->delete(@{$image->{vectors}}) if exists $image->{vectors};
		delete $self->{image};
	}
}

sub image {
	my $self = shift;
	@_ ? $self->{image}->{shift()} : $self->{image}
}

sub icon {
	my $self = shift;
	return $self->action('icon') || $self->scribbler->icon('call_' . $self->action('call'))
}

sub selected {
	my $self = shift;
	my $canvas = $self->canvas;
	if (@_) {
		my $selected = shift;
		if ($self->image) {
			if ($selected && !$self->{selected}) {
				$canvas->move($self->image('tile'), -$MINOR_GRID, -$MINOR_GRID);
				$canvas->addtag('full_only', 'withtag', $self->image('shadow'));
				$canvas->itemconfigure($self->image('shadow'), -state => 'normal');
				$canvas->raise($self->image('shadow'), '<lines>');
				$canvas->raise($self->image('tile'), 'all');
				$self->{selected} = 1
			} elsif (!$selected && $self->{selected}) {
				$canvas->move($self->image('tile'), $MINOR_GRID, $MINOR_GRID);
				$canvas->dtag($self->image('shadow'), 'full_only');
				$canvas->itemconfigure($self->image('shadow'), -state => 'hidden');
				$canvas->raise($self->image('tile'), $self->image('shadow'));
				$self->{selected} = 0
			}
		}
	}
	return $self->{selected} || 0
}

sub edit {
	my $self = shift;
	if (my $editor = $self->editor) {
		my $mw = $self->scribbler->mainwindow;
		$editor->transient($mw);
		$editor->protocol('WM_DELETE_WINDOW' => sub {$self->{'done'} = 0});
		$self->{done} = '';
		$editor->grab;
		$editor->Popup(-popover => $mw, -overanchor => 'c', -popanchor => 'c');
		$editor->waitVariable(\$self->{done});
		$editor->withdraw;
		$editor->grabRelease;
		$self->callRestore;
		$self->reimage;
		my $okay = $self->{done};
		delete $self->{done};
		return $okay
	} else {
		return 'okay'
	}
}

sub editor {
	return undef
}

sub canCall {
	my $self = shift;
	$self->subroutine->canCall
}

sub changeColors {
	my ($self, $oldcolor, $newcolor) = @_;
	if (($self->{action}->{call} || '') eq $oldcolor) {
		$self->{action}->{call} = $newcolor;
		$self->{call} = $newcolor if ($self->{call} || '') eq $oldcolor;
		$self->createImage;
		$self->redraw;
		$self->parent->reactivate;
	}
}

1;