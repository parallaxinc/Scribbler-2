package Scribbler::Worksheet;
use strict;

use Carp qw/cluck/;
use Digest::MD5 qw/md5_hex/;
use XML::Simple;
use File::Basename;
use File::Spec;
use Data::Dump qw/dump/;

use Scribbler::Subroutine;
use Scribbler::ReturnTile;
use Scribbler::MotionTile;
use Scribbler::Loop;
use Scribbler::LoopExitTile;
use Scribbler::FlagActionTile;
use Scribbler::ConditionalArray;
use Scribbler::AndConditionalTile;
use Scribbler::SensorReadTile;
use Scribbler::LedTile;
use Scribbler::PauseTile;
use Scribbler::SequencerTile;
use Scribbler::Constants;
use Scribbler::ComputeTile;

use base qw/Scribbler::Atom/;

sub new {
	my ($invocant, $parent) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = Scribbler::Atom::new($class, $parent,
		grid => {},
		selected => [],
		nominate => {},
		totalcalls => 0,
		counters => 0,
		version => $VERSION,
		name => '',
	);
	$self =~ m/HASH\(([^\)]+)\)/;
	$self->id("WS:$1");
	$self->activateRoot;
	$self->dirty(0);
	return $self; 
}

sub emitCode {
	my $self = shift;
	my $action = shift;
	my $scribbler = $self->scribbler;
	$self->queryAutoRead;
	$self->{countlevel} = 0;
	$self->{maxcount} = 0;
	$self->{rompointer} = $FIRST_ROM_ADDR;
	$self->{indent} = 0;
	$self->{code} = $self->scribbler->code('Preamble');
	$self->{rom} = [];
	$self->{required} = {};
	foreach my $color (@COLORS) {
		$self->{countlevel} = $self->{maxcount};
		if (my $subroutine = $self->findChildrenWith(color => $color)) {
			if ($subroutine->active == 1) {
				$self->appendCode($scribbler->codeHeader(($color eq $ROOT_COLOR ? 'Main Program: ' : 'Subroutine: ') . ucfirst $color) . "\n");
				$subroutine->emitCode
			}
		}
	}
	my @req = _getRequirements($scribbler, keys %{$self->{required}});
	$self->appendCode($self->scribbler->code($_)) foreach sort @req;
	$self->appendCode($self->scribbler->code('Postscript'));
	if (my @rom = @{$self->{rom}}) {
		$self->appendCode($scribbler->codeHeader('EEPROM Data'));
		$self->appendCode("DATA \@$FIRST_ROM_ADDR,");
		$self->indentCode;
		my $codeline = '';
		foreach (0 .. @rom - 1) {
			$codeline .= $rom[$_];
			$codeline .= ',' if $_ < @rom - 1;
			$codeline .= $_ == @rom - 1 || ($_ - 1) % 16 == 0 ? "\n" : ' '
		}
	}
	if (open(BS2, ">$TEMP_DIR/temp.spin")) {
		print BS2 $self->{code};
		close BS2;
		$self->tokenizeFile("$TEMP_DIR/temp.spin", $action);
		#unlink "$TEMP_DIR/temp.bs2"
	} else {
		print $self->{code}
	}
}

sub saveFile {
	my $self = shift;
	my $scribbler = $self->scribbler;
	my $mw = $scribbler->mainwindow;
	my $defaultfile = $self->{filename} || $scribbler->init('lastfile') || $scribbler->userdir . '\*.scb';
	my $defaultdir = File::Spec->canonpath(dirname($defaultfile));
	$defaultdir = $scribbler->userdir if substr($defaultdir, 0, length($INIT_DIR)) eq $INIT_DIR;
	my $defaultname = basename($defaultfile);
	while (
		my $savefile = $mw->getSaveFile(
			-title => $scribbler->translate('Save worksheet as') . ' ...',
			-initialdir => $defaultdir,
			-initialfile => $defaultname,
			-defaultextension => '.scb',
			-filetypes => [['Scribbler Files' => '.scb'], ['All Files' => '.*']]
		)
	) {
		if (open SCB, ">$savefile") {	
			my $code = XMLout($self->encode);
			my $digest = uc md5_hex($code);
			print SCB "<!-- Generated code: DO NOT EDIT! Any changes will void this file. -->\n<!-- $digest -->\n$code";
			close SCB;
			$self->name(basename($savefile));
			$self->{filename} = $savefile;
			$scribbler->init('lastfile' => $savefile);
			$self->dirty(0);
			last
		} else {
			return if $scribbler->dialog(-text => "I can't write to the chosen file. Please pick another.", -buttons => ['okay', 'cancel']) eq 'cancel'
		}
	}	
}

sub loadFile {
	my $self = shift;
	return unless $self->querySave;
	my $scribbler = $self->scribbler;
	my $mw = $scribbler->mainwindow;
	my $defaultfile = $scribbler->init('lastfile') || "$INIT_DIR\\Samples\\" . $self->{name} . ".scb";
	my $defaultdir = File::Spec->canonpath(dirname($defaultfile));
	my $defaultname = basename($defaultfile);
	while (
		my $loadfile = @_ ? shift : $mw->getOpenFile(
			-title => $scribbler->translate('Load worksheet') . ' ...',
			-initialdir => $defaultdir,
			-initialfile => $defaultname,
			-defaultextension => '.scb',
			-filetypes => [['Scribbler Files' => '.scb'], ['All Files' => '.*']]
		)
	) {
		#print "$loadfile\n";
		if (open SCB, "<$loadfile") {
			<SCB>;
			my $digest = (<SCB> =~ m/<!--\s*([0-9A-F]+)\s*-->/)[0];
			local $/ = undef;
			my $code = <SCB>;
			if ($digest && $digest eq uc md5_hex($code)) {
				$self = $self->_newFile;
				my $code = XMLin($code, ForceArray => qr/^_/);
				$code = recode($code);
				$self->decode($code);
				$_->redraw foreach $self->offspring;
				$self->activateRoot;
				$_->reactivate foreach grep {ref($_) =~ m/Tile$/} $self->offspring;
				$self->name(basename($loadfile));
				$self->{filename} = $loadfile;
				$scribbler->init('lastfile' => $loadfile);
				$self->dirty(0);
				last
			} else {
				return if $scribbler->dialog(-text => 'Chosen file is not a valid Scribbler file. Please pick another.', -buttons => ['okay', 'cancel']) eq 'cancel'
			}
		} else {
			return if $scribbler->dialog(-text => "I can't read the chosen file. Please pick another.", -buttons => ['okay', 'cancel']) eq 'cancel'
		}
	}	
}
		
sub newFile {
	my $self = shift;
	return unless $self->querySave;
	$self->_newFile;
	$self->activateRoot;
	$self->dirty(0);
	return $self;
}

sub _newFile {
	my $self = shift;
	$self->deleteChildren($self->children);
	$self->name('');
	return $self;
}

sub activateRoot {
	my $self = shift;
	my $subroutine = $self->subroutine($ROOT_COLOR);
	$subroutine->reactivate(1);
	$self->scribbler->tooltip(
		$self->canvas,
		{ $subroutine->child(0)->image('tile') => 'Program starts here.',
			$subroutine->child(-1)->image('tile') => 'Program ends here.'
		}
	);	
}

sub encode {
	my $self = shift;
	$self->queryAutoRead;
 	my $ref	= ref $self;
 	$ref =~ s/:+/_/g;
	return {
		class => $ref,
		version => $VERSION,
		autoreadsensors => $self->init('autoreadsensors'),
		_children => [map {recode($_)} $self->children]
	}
}

sub queryAutoRead {
	my $self = shift;
	my $auto = $self->init('autoreadsensors');
	$auto = $self->scribbler->init('autoreadsensors') unless defined $auto;
	if ($auto == 1) {
		$auto = 0 if grep {ref($_) eq 'Scribbler::SensorReadTile'} $self->offspring
	}
	$self->init(autoreadsensors => $auto);
}

sub recode {
	my $self = shift;
	return $self unless my $ref = ref $self;
	my $hash = {};
	if ($ref =~ s/:+/_/g) {
		$hash->{class} = $ref
	}
	foreach my $key (grep {$_ !~ m/^(parent|image|size|location|selected)$/} sort keys %$self) {
		my $value = $self->{$key};
		if (my $refv = ref $value) {
			if ($refv =~ m/Scribbler::/) {
				$hash->{$key} = recode($value)
			} elsif ($refv eq 'HASH') {
				$hash->{$key} = recode($value)
			} elsif ($refv eq 'ARRAY') {
				$key = "_$key" unless $key =~ s/^_//;
				$hash->{$key} = [map {recode($_)} @$value]
			} else {
				$hash->{$key} = $$value
			}
		} else {
			$hash->{$key} = $value if defined $value
		}
	}
	return $hash
}

sub tokenizeFile {
	my $self = shift;
	my $scribbler = $self->scribbler;
	my $file = '"' . File::Spec->canonpath(shift()) . '"';
	my $action = shift;
	if ($action eq 'run' and my $loader = $self->scribbler->loader) {
		my $status = $scribbler->getrun(qq("$loader" /lib "$INIT_DIR/editor" /eeprom /gui off $file), "Uploading...");
		#print $status;
		if ($status =~ m/err:/i) {
			if ($status =~ m/err:3[0-4]\d/i) {
				$scribbler->dialog(-text => [
					'No connection could be made to your Scribbler.', "\n\n",
					'Please verify the following:',"\n\n",
					'1. ', 'The data cable is plugged in at both ends.', "\n",
					'2. ', 'Your Scribbler is turned on.', "\n",
					'3. ', 'You have fresh batteries installed.'
				],
				-justify => 'left')
			} else {
				$scribbler->dialog(-text => ["An error occurred while uploading your program.\n\nPlease try again."], -button => 'Okay')
			}
			$status =~ s/\s*[\r\n]+\s*/;/gs;
			$status =~ s/[\x00-\x1f\x80-\xff]//gs;
			$status =~ s/[;\s]+$//s;
			$scribbler->init(lasterror => $status)
		} else {
			$scribbler->dialog(-text => "Upload successful!", -timeout => 2000)
		}
	} elsif ($action eq 'edit' and my $editor = $self->scribbler->editor) {
		my $mw = $scribbler->mainwindow;
		$mw->withdraw;
		$scribbler->run(qq("$editor" /newinstance $file));
		$mw->deiconify;
		$mw->raise
	}
}

sub appendCode {
	my $self = shift;
	my $code = shift;
	if (defined $code && $code ne '') {
		chomp $code;
		$self->{code} .= ' ' x ($CODE_INDENT_INCREMENT * $self->{indent}) . $code . "\n"
	}
}

sub indentCode {
	my $self = shift;
	$self->{indent}++
}

sub unindentCode {
	my $self = shift;
	$self->{indent}--
}

sub appendRom {
	my $self = shift;
	push @{$self->{rom}}, @_
}

sub nextCounter {
	my $self = shift;
	my $counter = 'Counter' . $self->{countlevel}++;
	$self->{maxcount}++ if $self->{countlevel} > $self->{maxcount};
	return $counter
}

sub prevCounter {
	my $self = shift;
	$self->{countlevel}--
}

sub emitCall {
	my $self = shift;
	my $call = shift;
	$self->appendCode($call);
	$call =~ s/\(.*//;
	$self->{required}->{lc $call} = 1
}

sub _getRequirements {
	my $scribbler = shift;
	my @req = @_;
	my %req = map {$_ => 1} @req;
	my $size = @req;
	foreach (@req) {
		$req{$_} = 1 foreach $scribbler->required($_)
	}
	if (keys %req > $size) {
		return _getRequirements($scribbler, keys %req)
	} else {
		return keys %req
	}
}

sub clone {
	my $self = shift;
}	

sub redraw {
	my $self = shift;
	my ($x, $y) = (0, 0);
	foreach my $color (@COLORS) {
		if (my $subroutine = $self->findChildrenWith(color => $color)) {
			$subroutine->location($x, 0);
			my ($w, $h) = $subroutine->size;
			$x += $w;
			$y = $h if $h > $y			
		}
	}
	$self->size($x, $y);
	$self->scribbler->size($x, $y);
}

#------------------------------------------------------------------------

sub insertNewSubroutine {
	my $self = shift;
	my $color = shift;
	$self->insertSubroutine(Scribbler::Subroutine->new($self), $color);
}

sub insertSubroutine {
	my $self = shift;
	my $subroutine = shift;
	my $color = shift;
	$subroutine->color($color);
	$self->deleteChildren($self->findChildrenWith(color => $subroutine->color));
	$self->appendChildren($subroutine);
	$self->redraw;
	$self->dirty(1);
	return $subroutine
}

sub sub_color {
	my $self = shift;
	my $sub = shift;
	return ref $sub ? ($sub, $sub->color) : ($self->findChildrenWith(color => $sub), $sub)
}

sub availableColors {
	my $self = shift;
	my %include = map {$_ ? ($_ => 1) : ()} @_;
	return grep {!$self->findChildrenWith(color => $_) || $include{$_}} @COLORS
}

sub insertClipboard {
	my $self = shift;
	my $clipboard = $self->scribbler->clipboard;
	return unless $clipboard->children;
	if (my $before = $self->{nominated}) {
		$before = $before->parent while $before->findMe == 0;
		my $block = $before->parent;
		my %cancall = map {($_ => 1)} $before->subroutine->canCall;
		my $sameworksheet = $clipboard->worksheet eq $self;
		foreach ($clipboard->children) {
			my $clone = $_->clone($block);
			$clone->createImage if $clone->can('createImage');
			$block->insertBefore($before, $clone);
			$clone->callRestore if $sameworksheet;
		}
		$self->dirty(1);
		$before->subroutine->countCounters;
	}
	$self->selectRemoveAll;
}		

sub insertNew {
	my $self = shift;
	my $invocant = shift;
	my $class = ref $invocant || $invocant;
	my $dirty = $self->dirty;
	if ($class eq 'Subroutine') {
		if (my $color = ($self->availableColors)[0]) {
			my $subroutine = $self->insertNewSubroutine($color);
			$self->selectTile($subroutine->begin);
			if ($self->editSelectedNew eq 'okay') {
				$self->redraw;
				$self->dirty(1)
			} else {
				$self->deleteSelected;
				$self->dirty($dirty)
			}
		}		
	} elsif (my $before = $self->{nominated}) {
		$before = $before->parent while $before->findMe == 0;
		my $subroutine = $before->subroutine;
		my $block = $before->parent;
		my $atom = "Scribbler::$class"->new($block);
		$block->insertBefore($before, $atom);
		$self->selectTile($atom);
		if ($self->editSelectedNew eq 'okay') {
			$self->dirty(1);
			$subroutine->countCounters if $class eq 'Loop'
		} else {
			$self->deleteSelected;
			$self->dirty($dirty)
		}
	}
	$self->selectRemoveAll;
	return undef
}

sub editSelectedNew {
	my $self = shift;
	return ($self->selected)[0]->edit
}	

sub editSelected {
	my $self = shift;
	if (my @tiles = $self->selected) {
		my $okay = $tiles[0]->editMenu(scalar @tiles);
		if ($okay eq 'delete') {
			$self->deleteSelected
		} elsif ($okay eq 'cut') {
			$self->cutSelected
		} elsif ($okay eq 'copy') {
			$self->copySelected;
			$self->selectRemoveAll
		} else {
			$self->selectRemoveAll
		}
		$self->dirty(1) if $okay eq 'okay';
		return $okay
	} else {
		return 1
	}
}

sub copySelected {
	my $self = shift;
	$self->_modifySelected(1, 0)
}

sub cutSelected {
	my $self = shift;
	$self->_modifySelected(1, 1)
}

sub deleteSelected {
	my $self = shift;
	$self->_modifySelected(0, 1)
}

sub _modifySelected {
	my ($self, $copy, $delete) = @_;
	return unless $self->selected;
	my $scribbler = $self->scribbler;
	if ((my $first = ($self->selected)[0])->isa('Scribbler::Subroutine')) {
		$self->selectBlockBody($first) && $self->_modifySelected($copy, $delete);
		$self->deleteChildren($first) if $delete && $first->reactivate == 0
	} else {
		$scribbler->clipboard($self, [map {$_->clone($scribbler)} $self->selected]) if $copy;
		if ($delete) {
			my $last = ($self->selected)[-1];
			$self->selectRemoveAll;
			my $subroutine = $first->subroutine;
			$first->parent->deleteSiblings($first, $last);
			$subroutine->countCounters;
			$self->dirty(1)
		}
	}
}	

sub selectBlockBody {
	my $self = shift;
	return () unless @_ && (my $block = shift)->isa('Scribbler::AtomBlock');
	$self->selectRemoveAll;
	if ((my @children = $block->children) >= 3) {
		$self->selectTile($children[1]);
		$self->selectTo($children[-2]);
	}
	return $self->selected
}		

sub name {
	my $self = shift;
	my $scribbler = $self->scribbler;
	if (@_) {
		$self->{name} = shift;
		$scribbler->retitle($self->{name}) unless defined $scribbler->worksheet && $self ne $scribbler->worksheet
	}
	return $self->{name}
}

sub id {
	my $self = shift;
	return @_ ? $self->{id} = shift : $self->{id}
}

sub gridRemove {
	my $self = shift;
	my $grid = $self->{grid};
	while (@_) {
		my $tile = shift;
		if (my $xy = $grid->{$tile}) {
			delete $grid->{$xy}->{$tile};
			delete $grid->{$xy} unless %{$grid->{$xy}};
			delete $grid->{$tile}
		}
	}
}

sub grid {
	my $self = shift;
	my $x = shift;
	my ($tile, $xy);
	if (ref $x) {
		$tile = $x;
		if (@_) {
			my ($x, $y) = @_;
			return undef if $x < 0 || $y < 0;
			$xy = sprintf("%3.3d,%3.3d", @_[0, 1]);
			$self->_assignGrid($tile, $xy)
		}
		return $self->{grid}->{$tile} ? split(',', $self->{grid}->{$tile}) : undef
	} else {
		my $y = shift;
		return undef if $x < 0 || $y < 0;
		$xy = sprintf("%3.3d,%3.3d", $x, $y);
		if (@_) {
			my $tile = shift;
			$self->_assignGrid($tile, $xy)
		}
		my $tiles = $self->{grid}->{$xy} || {};
		return wantarray ? values %$tiles : (values %$tiles)[0]
	}
}

sub _assignGrid {
	my ($self, $tile, $xy) = @_;
	if (my $oldxy = $self->{grid}->{$tile}) {
		delete $self->{grid}->{$oldxy}->{$tile};
		delete $self->{grid}->{$oldxy} unless keys %{$self->{grid}->{$oldxy}}
	}
	$self->{grid}->{$xy}->{$tile} = $tile;
	$self->{grid}->{$tile} = $xy
}

sub selectedSubroutine {
	my $self = shift;
	@{$self->{selected}} ? $self->{selected}->[0]->subroutine : undef
}

sub nominatedSubroutine {
	my $self = shift;
	$self->{nominated} ? $self->{nominated}->subroutine : undef
}

sub nominateTile {
	my $self = shift;
	if (@_) {
		my $x = shift;
		$self->{nominated} = ref $x ? $x : $self->grid($x, shift());
	}
	return $self->{nominated}
}

sub aboveNominee {
	my $self = shift;
	my $nominee = $self->{nominated};
	if ($nominee) {
		my ($x, $y) = $self->grid($nominee);
		return $self->grid($x, $y - 1)
	} else {
		return undef
	}
}

sub nominateRemove {
	my $self = shift;
	my $tile = $self->nominateTile;
	undef $self->{nominated};
	return $tile
}

sub selectNominee {
	my $self = shift;
	$self->selectTile($self->nominateTile);
}

sub selectToNominee {
	my $self = shift;
	$self->selectTo($self->nominateTile);
}

sub selectTile {
	my $self = shift;
	my $tile = shift;
	$self->selectRemoveAll;
	$self->{selectbegin} = $tile;
	$self->{selectend} = $tile;
	$self->_makeSelection;
}

sub selectTo {
	my $self = shift;
	my $tile = shift;
	my $begin = $self->{selectbegin};
	my $end = $self->{selectend};
	if ($tile && $begin && $self->grid($begin) && $begin->parent && $begin->subroutine eq $tile->subroutine) {
		if ($end) {
			if (($self->grid($tile))[1] <= ($self->grid($begin))[1]) {
				$self->{selectbegin} = $tile
			} elsif (($self->grid($tile))[1] >= ($self->grid($end))[1]) {
				$self->{selectend} = $tile
			}
		} else {
			$self->{selectend} = $tile
		}
		$self->_makeSelection;
	} else {
		$self->selectTile($tile)
	}
}

sub _makeSelection {
	my $self = shift;
	my $begin = $self->{selectbegin};
	my $end = $self->{selectend};
	$self->selectRemove;
	return if !$begin || !$end || $begin->subroutine ne $end->subroutine;
	do {
		$begin = $begin->parent while !$begin->isa('Scribbler::Subroutine') && ($begin eq $begin->parent->begin || $begin eq $begin->parent->end);
		$end = $end->parent while !$end->isa('Scribbler::Subroutine') && ($end eq $end->parent->begin || $end eq $end->parent->end);
		if ($end->depth > $begin->depth) {
			$end = $end->parent
		} elsif ($begin->depth > $end->depth) {
			$begin = $begin->parent
		} elsif ($begin->parent ne $end->parent) {
			$begin = $begin->parent;
			$end = $end->parent
		}
	}	until ($begin->parent eq $end->parent);
	$self->{selected} = $begin eq $end ? [$begin] : [$begin->parent->siblingsBetween($begin, $end)];
	$_->selected(1) foreach @{$self->{selected}};
	return $self->selected
}

sub selectRemoveAll {
	my $self = shift;
	$self->selectRemove;
	undef $self->{selectbegin};
	undef $self->{selectend}
}

sub selectRemove {
	my $self = shift;
	$_->selected(0) foreach @{$self->{selected}};
	$self->{selected} = [];
}

sub selected {
	my $self = shift;
	return @{$self->{selected}}
}

sub subroutine {
	my ($self, $color) = @_;
	return undef unless $color;
	$self->findChildrenWith(color => $color) or $self->insertNewSubroutine($color)
}

sub subroutines {
	my $self = shift;
	return $self->children
}

sub subroutineColors {
	my $self = shift;
	return map {$_->color} $self->children
}

sub showFull {
	my $self = shift;
	my $ws = $self->id;
	my $canvas = $self->scribbler->canvas;
	$canvas->itemconfigure("$ws&&zoom_only", -state => 'hidden');
	$canvas->itemconfigure("($ws||<grid>)&&full_only", -state => 'normal')
}

sub showZoom {
	my $self = shift;
	my $ws = $self->id;
	my $canvas = $self->scribbler->canvas;
	$canvas->itemconfigure("($ws||<grid>)&&full_only", -state => 'hidden');
	$canvas->itemconfigure("$ws&&zoom_only", -state => 'normal')
}

sub hide {
	my $self = shift;
	my $ws = $self->id;
	$self->scribbler->canvas->itemconfigure($ws, -state => 'hidden')
}

sub totalCalls {
	my $self = shift;
	$self->{'totalcalls'} += @_ ? shift : 0
}

sub changeColors {
	my ($self, $oldcolor, $newcolor) = @_;
	if (my $child = $self->findChildrenWith(color => $oldcolor)) {
		$child->color($newcolor);
		$self->SUPER::changeColors($oldcolor => $newcolor);
		$self->redraw;
		$self->dirty(1)
	}
}

sub counters {
	my $self = shift;
	my $counters = 0;
	$counters += $_->containedCounterDepth foreach $self->children;
	return $self->{counters} = $counters;
}

sub dirty {
	my $self = shift;
	return @_ ? $self->{dirty} = shift : $self->{dirty}
}

sub querySave {
	my $self = shift;
	return 1 unless $self->dirty;
	my $title = shift;
	my $scribbler = $self->scribbler;
	my $name = $self->name;
	$name =  '"' . $name . '" ' if $name;
	my $response = $scribbler->dialog(
		-title => $title,
		-text => $scribbler->translate("Worksheet") . ' ' . $name . $scribbler->translate("has not been saved. Save it now?"),
		-buttons => ['okay', 'no', 'cancel']
	);
	$self->saveFile if $response eq 'okay';
	return $response eq 'okay' || $response eq 'no'
}

1;