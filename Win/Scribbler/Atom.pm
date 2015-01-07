package Scribbler::Atom;
use strict;
use Carp qw/cluck confess/;
use Scribbler::Constants;

my $Scribbler;

sub new {
	my $invocant = shift;
	my $class = ref $invocant || $invocant;
	my $parent = shift;
	my $self = {
		subclass => '',
		action => {},
		call => undef,
		parent => $parent,
		children => [],
		image => {}, 
		size => [0,0],
		active => 0,
		activeout => 0,
		selected => 0
	};
	bless $self, $class;
	$self->configure(@_);
	$Scribbler = $self if $class eq 'Scribbler';
	return $self
}

sub emitCall {
	my $self = shift;
	my $call = $self->call;
	$self->worksheet->appendCode(ucfirst $call) if $call
}

sub decode {
	my $self = shift;
	my $code = shift;
	$self->configure(map {($_ => $code->{$_})} grep {$_ !~ m/^(children|class)$/} keys %$code);
	foreach my $codechild (@{$code->{children}}) {
		my $subclass = $codechild->{subclass} || '';
		my $class = $codechild->{class};
		$class =~ s/_/::/g;
		my $selfchild = $class->new($self);
		foreach ($selfchild->offspring) {
			undef $_->{parent};
			undef $_->{children}
		}
		$selfchild->{children} = [];
		push @{$self->{children}}, $selfchild;
		$selfchild->{parent} = $self;
		$selfchild->decode($codechild)
	}
}

sub configure {
	my $self = shift;
	while (@_) {
		my $key = shift;
		$self->{$key} = shift if @_
	}
	return $self
}

#------------------------------------------------------------------------

sub selected {
	my $self = shift;
	if (@_) {
		my $sel = shift;
		$self->{selected} = $sel;
		$_->selected($sel) foreach $self->children
	}
	return $self->{selected}
}

sub init {
	my $self = shift;
	my $key = shift;
	return @_ ? $self->{init}->{$key} = shift : $self->{init}->{$key}
}

sub scribbler {
	return $Scribbler
}

sub canvas {
	my $self = shift;
	return $self->{canvas} || $Scribbler->canvas
}

sub worksheet {
	my $self = shift;
	return $self->enclosing('Scribbler::Worksheet')
}

sub subroutine {
	my $self = shift;
	return $self->enclosing('Scribbler::Subroutine')
}

sub loop {
	my $self = shift;
	return $self->enclosing('Scribbler::Loop')
}

sub enclosing {
	my $self = shift;
	my $enclosing = shift;
	my $class = ref $enclosing || $enclosing || 'Scribbler::AtomBlock';
	return $self->isa($class) ? $self : $self->parent ? $self->parent->enclosing($class) : undef
}

sub antecedentTile {
	my $self = shift;
	do {
		$self = $self->antecedent or return undef
	} until (ref($self) =~ m/Tile$/);
	return $self
}

sub antecedent {
	my $self = shift;
	my $parent = $self->parent or return undef;
	if (my $index = $parent->findChild($self)) {
		return $parent->child($index - 1)
	} else {
		return $parent->antecedent
	}
}

sub consequent {
	my $self = shift;
	my $parent = $self->parent || return undef;
	if ((my $index = $parent->findChild($self)) < $parent->children - 1) {
		return $parent->child($index + 1)
	} else {
		return $parent->consequent
	}
}

sub subclass {
	my $self = shift;
	return @_ ? $self->{subclass} = shift : $self->{subclass}
}

sub action {
	my $self = shift;
	return $self->access('action', @_)
}

sub access {
	my $self = shift;
	my $key = shift;
	my $subkey;
	if (@_) {
		$subkey = shift;
		while (@_) {
			my $value = shift;
			$self->{$key}->{$subkey} = $value;
			$subkey = shift if @_
		}
		return $self->{$key}->{$subkey}
	} else {
		return $self->{$key}
	}
}

sub clone {
	my $self = shift;
	my $parent = shift;
	my $clone = $self->new($parent);
	my @children = map {$_->clone($clone)} $self->children;
	$clone->children(@children);
	return $clone
}

sub deleteChildren {
	my $self = shift;
	while (@_) {
		if (my $child = shift) {
			($self->adoptSiblings($self, $child, $child))[0]->_deleteAll
		}
	}
}

sub deleteOffspring {
	my $self = shift;
	$_->_deleteAll foreach $self->children;
	$self->{children} = [];
	$self->redraw;
	$self->reactivate;
}

sub _deleteAll {
	my $self = shift;
	$_->_deleteMe foreach ($self->offspring, $self)
}

sub deleteSiblings {
	my $self = shift;
	$_->_deleteAll foreach $self->adoptSiblings(undef, @_)
}

sub _deleteMe {
	my $self = shift;
	$self->adopt;
	$self->orphan
}	

sub adoptSiblings {
	my $self = shift;
	my $parent = shift;
	if (my @range = $self->siblingIndexRange(@_)) {
		my @siblings = splice @{$self->{children}}, $range[0], $range[1] - $range[0] + 1;
		$_->adoptAll($parent) foreach @siblings;
		$self->redraw;
		$self->reactivate;
		return @siblings
	} else {
		return ()
	}
}

sub adoptAll {
	my $self = shift;
	$_->adopt($_->parent) foreach ($self->offspring, $self);
	$self->parent(shift)
}

sub adopt {
	my $self = shift;
	$self->call('');
	$self->deleteImage if $self->can('deleteImage');
	undef $self->{location};
	$Scribbler->worksheet->gridRemove($self);
	$self->parent(shift);
}

sub orphan {
	my $self = shift;
	undef $self->{parent};
}

sub parent {
	my $self = shift;
	@_ ? $self->{parent} = shift : $self->{parent}
}

sub offspring {
	my $self = shift;
	my @children = $self->children;
	return ((map {$_->offspring} @children), @children)
}

sub children {
	my $self = shift;
	if (@_) {
		$self->deleteOffspring;
		while (@_) {
			my $child = shift;
			push @{$self->{children}}, ref($child) eq 'ARRAY' ? @$child : $child
		}
	}
	return @{$self->{children}}
}

sub begin {
	my $self = shift;
	return $self->child(0)
}

sub end {
	my $self = shift;
	return $self->child(-1)
}

sub appendChildren {
	my $self = shift;
	$self->insertBefore(undef, @_);
	return wantarray ? @_ : shift
}

sub insertBefore {
	my $self = shift;
	my $children = $self->{children};
	my $before = shift;
	$_->parent($self) foreach @_;
	my $pos = $before && $self->findChild($before) || @$children;
	$pos-- if $pos && $self->child($pos - 1)->subclass =~ m/_end/;
	splice @$children, $pos, 0, @_;
	$self->redraw;
	$self->reactivate;
	return @$children
}	

sub siblingsBetween {
	my $self = shift;
	my @range = $self->siblingIndexRange(@_);
	return @range ? ($self->children)[$range[0] .. $range[1]] : ()
}

sub siblingIndexRange {
	my $self = shift;
	my ($from, $to) = (0, $self->children - 1);
	$from = $to = undef if $from > $to;
	$from = $self->findChild(shift()) if @_;
	$to = $self->findChild(shift()) if @_;
	return defined $from && defined $to ? ($from <= $to ? ($from, $to) : ($to, $from)) : ()
}

sub contains {
	my $self = shift;
	my $class = shift;
	return grep {$_->isa($class)} $self->offspring
}

sub findMe {
	my $self = shift;
	return $self->parent->findChild($self)
}	

sub findChild {
	my $self = shift;
	my $target = shift;
	return (grep {$self->child($_) eq $target} (0 .. $self->children - 1))[0];
}

sub findChildrenWith {
	my ($self, $key, $value) = @_;
	my @found = grep {$_->{$key} eq $value} $self->children;
	return wantarray ? @found : $found[0]
}

sub child {
	my $self = shift;
	my $index = shift;
	return $self->{children}->[$index]
}

sub callRestore {
	my $self = shift;
	if ($self->action('call') || $self->{call}) {
		my $wantcall = $self->action('call');
		$self->call($self->subroutine->canCall($wantcall) ? $wantcall : '');
		$self->reimage if $self->{image}
	}
}

sub call {
	my $self = shift;
	if (@_) {
		my $newcall = shift;
		my $prvcall = $self->{call};
		if (!defined $prvcall || $newcall ne $prvcall) {
			my $subroutine = $self->subroutine;
			$subroutine->deleteCall($prvcall) if $prvcall;
			$subroutine->addCall($newcall) if $newcall;
			if ($self->reactivate == 1) {
				$self->worksheet->subroutine($prvcall)->deleteActiveCall if $prvcall;
				$self->worksheet->subroutine($newcall)->addActiveCall if $newcall
			}
			$self->{call} = $newcall
		}
	}
	return $self->{call}
}

sub location {
	my $self = shift;
	if (@_) {
		my ($x, $y) = @_;
		my ($curx, $cury) = $self->location;
		if ($x != $curx || $y != $cury) {
			$self->{location} = [$x, $y];
			$self->redraw
		}
	}
	return ref $self->{location} ? @{$self->{location}} : (0, 999)
}

sub width {
	my $self = shift;
	return $self->{size} ? $self->{size}->[0] : 0
}

sub height {
	my $self = shift;
	return $self->{size} ? $self->{size}->[1] : 0
}

sub size {
	my $self = shift;
	if (@_) {
		my ($width, $height) = @_;
		if (! exists $self->{size} || $width != $self->{size}->[0] || $height != $self->{size}->[1]) {;
			$self->{size} = [$width, $height];
			$self->parent->redraw;
		}
	}
	return @{$self->{size} || [0,0]}
}

sub active {
	my $self = shift;
	return @_ ? $self->{active} = shift : $self->{active}
}

sub reactivate {
	my $self = shift;
	return 1 unless $self->worksheet;
	if (@_) {
		my $newactive = shift;
		my $oldactive = $self->{active};
		if (!defined($oldactive) || $newactive != $oldactive) {
			if ((my $call = $self->{call}) && ($newactive == 1 || $oldactive == 1)) {
				my $subroutine = $self->worksheet->subroutine($call);
				$newactive == 1 ? $subroutine->addActiveCall : $subroutine->deleteActiveCall;
				$subroutine->reactivate;
			}
			$self->{'active'} = $newactive;
		}
	}
	return $self->{'active'}
}

sub activeOut {
	my $self = shift;
	if (@_) {
		my $newactiveout = shift;
		my $oldactiveout = $self->{activeout};
		if (!defined($oldactiveout) || $newactiveout ne $oldactiveout) {
			$self->{'activeout'} = $newactiveout;
			$self->parent->reactivate
		}
	}
	return $self->{activeout}
}
		
sub priority {
	my $self = shift;
	return $self->parent ? $self->parent->priority : 1
}

sub depth {
	my $self = shift;
	my $depth = 0;
	until ($self->isa('Scribbler::Subroutine')) {
		$self = $self->parent;
		$depth++
	}
	return $depth
}

sub containedCounterDepth {
	my $self = shift;
	my $depth = $self->isa('Scribbler::Loop') && $self->action('reps') ? 1 : 0;
	my $childrendepth = 0;
	foreach my $child ($self->children) {
		my $childdepth = $child->containedCounterDepth;
		$childrendepth = $childdepth if $childdepth > $childrendepth
	}
	return $depth + $childrendepth
}

sub containedLoopDepth {
	my $self = shift;
	my $depth = $self->isa('Scribbler::Loop') ? 1 : 0;
	my $childrendepth = 0;
	foreach my $child ($self->children) {
		my $childdepth = $child->containedLoopDepth;
		$childrendepth = $childdepth if $childdepth > $childrendepth
	}
	return $depth + $childrendepth
}

sub counterDepth {
	my $self = shift;
	my $depth = 0;
	until ($self->isa('Scribbler::Subroutine')) {
		$depth++ if $self->isa('Scribbler::Loop') && $self->action('reps');
		$self = $self->parent
	}
	return $depth
}	

sub loopDepth {
	my $self = shift;
	my $depth = 0;
	until ($self->isa('Scribbler::Subroutine')) {
		$depth++ if $self->isa('Scribbler::Loop');
		$self = $self->parent
	}
	return $depth
}

sub changeColors {
	my $self = shift;
	$_->changeColors(@_) foreach $self->children
}

my ($Self, $EditMenu, %BtnEdit, %BtnCut);

sub editMenu {
	$Self = shift;
	my $scribbler = $Self->scribbler;
	$EditMenu = $Self->_createEditMenu unless $EditMenu;
	my $btnicon = $BtnEdit{icon};
	if (
		$Self->worksheet->selected > 1 ||
		$Self->isa('Scribbler::Subroutine') && $Self->color eq $ROOT_COLOR ||
		$Self->subclass eq 'exit'
	) {
		$btnicon->parent->packForget
	} else {
		my $icon = $Self->icon;
		$btnicon->configure(
			-pressimage => $scribbler->button($icon . '_press'),
			-offimage => $scribbler->button($icon . '_release')
		);
		$btnicon->parent->pack(-side => 'left')
	}
	$BtnCut{$_}->TurnOff foreach qw/copy cut trash/;
	my $mw = $scribbler->mainwindow;
	$EditMenu->transient($mw);
	$EditMenu->protocol('WM_DELETE_WINDOW' => sub {$Self->{'done'} = 0});
	$Self->{done} = '';
	$EditMenu->grab;
	$EditMenu->Popup(-popover => $mw, -overanchor => 'c', -popanchor => 'c');
	$EditMenu->waitVariable(\$Self->{done});
	$EditMenu->withdraw;
	$EditMenu->grabRelease;
	my $okay = $Self->{done};
	if ($okay eq 'icon') {
		$okay = $Self->edit;
		$Self->callRestore;
		$Self->reimage
	}
	delete $Self->{done};
	return $okay
}

sub _createEditMenu {
	my $self = shift;
	my $scribbler = $self->scribbler;
	my $mw = $scribbler->mainwindow->Toplevel(-title => $scribbler->translate('edit', 1));
	$scribbler->windowIcon($mw, 'select');
	$mw->withdraw;
	my $fraAction = $mw->Frame(-background => $BG)->pack(-side => 'left');
	my $fraEdit = $mw->Frame(-background => $BG)->pack(-side => 'right');
	my %tooltip = (icon => 'Edit the selection.', copy => 'Copy the selection.', cut => 'Cut the selection.', trash => 'Delete the selection.');
	foreach (qw/copy cut trash/) {
		$BtnCut{$_} = $fraEdit->ToggleButton(
			-width => $BTN_SZ,
			-height => $BTN_SZ,
			-ontrigger => 'release',
			-offtrigger => 'release',
			-latching => 1,
			-togglegroup => \%BtnCut,
			-onrelief => 'flat',
			-offrelief => 'flat',
			-pressrelief => 'flat',
			-onbackground => $BG,
			-offbackground => $BG,
			-cursor => 'hand2',
			-borderwidth => 0,
			-pressimage => $scribbler->button($_ . '_push'),
			-offimage => $scribbler->button($_ . '_off'),
			-onimage => $scribbler->button($_ . '_on'),
		)->pack(-side => 'left');
		$scribbler->tooltip($BtnCut{$_}, $tooltip{$_}) if $tooltip{$_}
	}
	foreach (qw/icon okay no/) {
		$BtnEdit{$_} = ($_ eq 'icon' ? $fraAction : $fraEdit)->ToggleButton(
			-width => $BTN_SZ,
			-height => $BTN_SZ,
			-ontrigger => 'release',
			-offtrigger => 'release',
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
		)->pack(-side => 'left');
		$scribbler->tooltip($BtnEdit{$_}, $tooltip{$_}) if $tooltip{$_}
	}
	return $mw
}

sub _evtClickButton {
	my $btn = shift;
	if ($btn eq 'okay') {
		my $copy = $BtnCut{copy}->on;
		my $cut = $BtnCut{cut}->on;
		my $trash = $BtnCut{trash}->on;
		$Self->{done} = $copy ? 'copy' : $cut ? 'cut' : $trash ? 'delete' : 'okay'
	} else {
		$Self->{done} = $btn
	}
}
			
sub query {
	my $self = shift;
	my $indent = shift || 0;
	my $selfname = $self;
	$selfname =~ s/=*(HASH|ARRAY).*//;
	my $tab = '  ' x $indent;
	print $selfname;
	if (ref($self) eq 'ARRAY') {
		if (grep {ref $_} @$self) {
			print " [\n";
			foreach (@$self) {
				print "$tab  ";
				query(defined $_ ? $_ : 'undef', $indent + 1)
			}
			print "$tab]\n"
		} else {
			print " [", join(',', @$self), "]\n"
		}
	} elsif (ref($self) =~ m/Scribbler/ && $indent == 0 || ref($self) eq 'HASH') {
		if (grep {ref $_} values %$self) {
			print " {\n";
			foreach (sort keys %$self) {
				print "$tab  $_ => ";
				query(defined $self->{$_} ? $self->{$_} : 'undef', $indent + 1)
			}
			print "$tab}\n"
		} else {
			print " {", join(', ', map {"$_ => " . (defined $self->{$_} ? $self->{$_} : 'undef')} keys %$self), "}\n"
		}
	} else {
		print "\n"
	}
	print "\n" unless $indent
}

sub drawVectors {
	my $self = shift;
	my @vectors = $self->drawLines(@_);
	my $canvas = $self->canvas;
	$canvas->itemconfigure($vectors[0], -arrow => 'last', -arrowshape => $ARROW);
	return @vectors
}

sub drawLines {
	my $self = shift;
	my $canvas = $self->canvas;
	return () unless ref(my $coords = shift);
	my (@coords, @lines);
	while (@$coords) {
		push @coords, $self->coords(shift @$coords, shift @$coords)
	}
	foreach (qw/full_only zoom_only/) {
		my $line = $canvas->createLine(
			@coords,
			-width => $_ eq 'full_only' ? $LINE_WIDTH : 1,
			-joinstyle => 'round',
			-tags => [$self->worksheet->id, $_],
			@_
		);
		$canvas->raise($line, '<lines>');
		push @lines, $line
	}
	return @lines
}

sub configureLines {
	my $self = shift;
	my $lines = shift;
	my $updown = shift;
	my $canvas = $self->canvas;
	foreach (@$lines) {
		$canvas->itemconfigure($_, @_);
		if ($updown eq 'raise') {
			$canvas->raise($_, '<lines>')
		} elsif ($updown eq 'lower') {
			$canvas->lower($_, '<lines>')
		}
	}
}	

sub coords {
	my (undef, $x, $y) = @_;
	return (int($x * $MAJOR_XGRID + $MINOR_GRID + 0.5), int($y * $MAJOR_YGRID + $MINOR_GRID + 0.5))
}

1;