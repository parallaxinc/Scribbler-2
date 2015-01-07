use strict;
#use lib '/jobs/perl/parallax/s2'; #Must comment out for perl2exe.
use Carp;
use Tk;
use Tk::ToggleButton;

require Tk::Pane;
require Tk::Compound;
require Tk::Scrollbar;
require Tk::Scale;
require Win32::Sound;
require Tk::Photo;
require Tk::Spinbox;
require Tk::Radiobutton;
require Tk::Balloon;
require Tk::Icon;
require Tk::Checkbutton;

require File::Glob;
require File::Find;
require File::Spec;
require File::Basename;
require XML::Simple;
require Digest::MD5;
require Win32;
require Win32::Process;

require "utf8_heavy.pl";
require "unicore/lib/SpacePer.pl";
require "unicore/To/Lower.pl";
require "unicore/To/Upper.pl";
require "unicore/To/Fold.pl";
require "unicore/lib/Digit.pl";
require "unicore/lib/Word.pl";
require "Encode/Unicode.pm";

use Scribbler;
use Scribbler::ActionTile;
use Scribbler::AndConditionalTile;
use Scribbler::Atom;
use Scribbler::AtomBlock;
use Scribbler::BlockArray;
use Scribbler::CallTile;
use Scribbler::ComputeTile;
use Scribbler::ConditionalArray;
use Scribbler::ConditionalBlock;
use Scribbler::ConditionalTile;
use Scribbler::Constants;
use Scribbler::ExitTile;
use Scribbler::EndTile;
use Scribbler::FlagActionTile;
use Scribbler::LedTile;
use Scribbler::Loop;
use Scribbler::LoopExitTile;
use Scribbler::LoopTile;
use Scribbler::MotionTile;
use Scribbler::PauseTile;
use Scribbler::ReturnTile;
use Scribbler::SensorReadTile;
use Scribbler::SequencerTile;
use Scribbler::SoundBite;
use Scribbler::SoundLibrary;
use Scribbler::SoundPlayer;
use Scribbler::Subroutine;
use Scribbler::SubroutineTile;
use Scribbler::Tile;
use Scribbler::Worksheet;

use Tie::IxHash;

#perl2exe_include XML::Parser::Style::Tree
#perl2exe_include PerlIO

#use encoding 'cp1252';

my $mw = Tk::MainWindow->new(-width => 720, -height => 540);
$mw->minsize(800,600);
$mw->protocol('WM_DELETE_WINDOW' => \&PowerDown);
$mw->withdraw;

my $Scribbler = Scribbler->new($mw);
$Scribbler->windowIcon($mw, 'gear_green');
$Scribbler->retitle('');

my $MenuColumns = 2;
my ($CurrIndex, $PrevIndex) = ('edit', 'edit');
my $Zoom = 1;
my ($AutoPanX, $AutoPanY, $AutoDelayX, $AutoDelayY);
my ($CursorX, $CursorY, $Cursor) = (0, 0, '');
my %Wheel = (left => 0, right => 0);
my ($MoveWindow, $Clicked);

my $MenuCommands = Tie::IxHash->new(
	new => {
		icon => 'new',
		onselect => sub {$Scribbler->worksheet->newFile},
		tip => 'Clear the worksheet.'
	},
	
	load => {
		icon => 'load',
		onselect => sub {$Scribbler->worksheet->loadFile},
		tip => 'Load a worksheet.'
	},
	
	save => {
		icon => 'save',
		onselect => sub {$Scribbler->worksheet->saveFile},
		tip => 'Save a worksheet.'
	},
	
	run => {
		icon => 'run',
		onselect => sub {$Scribbler->worksheet->emitCode('run')},
		tip => 'Copy the program to the Scribbler.'
	},
	
	edit => {
		icon => 'edit',
		onselect => sub {$Scribbler->worksheet->emitCode('edit')},
		tip => 'View the Propeller program.'
	},
	
	restore => {
		icon => 'immaculate',
		onselect => sub {$Scribbler->worksheet->tokenizeFile("$INIT_DIR/default.binary", 'run')},
		tip => 'Restore the factory program.'
	},
	
	calibrate => {
		icon => 'calibrate',
		onselect => -e "$INIT_DIR/calibrate.binary" 
			? sub {$Scribbler->worksheet->tokenizeFile("$INIT_DIR/calibrate.binary", 'run')}
			: \&notImplemented,
		tip => 'Upload the calibration program.'
	},
	
	monitor => {
		icon => 'monitor',
		onselect => sub {if (my $monitor = $Scribbler->monitor) {$Scribbler->start($monitor)} else {notImplemented()}},
		tip => "Monitor the Scribbler's sensors."
	},
	
	help => {
		icon => 'query',
		onselect => sub {if (my $help = $Scribbler->help) {$Scribbler->start($help)} else {notImplemented()}},
		tip => 'Click for help. Right-click to toggle tooltips.'
	}
	
);

sub notImplemented {
	$Scribbler->dialog(-text => $Scribbler->translate('This function is not yet implemented') . '.', -buttons => ['okay'])
}

my %Default = (
	onmove => \&MoveInsert,
	autopan => 1,
	pointer => 'crosshair',
	caninsert_h => sub {0},
	caninsert_v => sub {
		my $nominee = shift;
		return !$nominee->isa('Scribbler::AndConditionalTile')
	},
	onrightclick => \&ForceEdit
);

my %btnObjects;
my $ObjectButtons = Tie::IxHash->new(

	zoom => {
		icon => 'zoom',
		pointer => 'ul_angle',
		onclick => \&ZoomIn,
		autopan => 0,
		caninsert_v => sub{0},
		tip => 'Zoom out'
	},
	
	edit => {
		icon => 'hand',
		pointer => 'left_ptr',
		onmove => \&MoveSelect,
		oncenterclick => \&Query, 
		ondoubleclick => \&SelectItem,
		onclick => \&SelectToItem,
		onrightclick => \&EditNominee,
		tip => 'Select and edit'
	},
	
	paste => {
		icon => 'paste',
		onclick => sub{$Scribbler->worksheet->insertClipboard},
		caninsert_h => sub {
			return 0 unless ref $Scribbler->clipboard->begin;
			my $nominee = shift;
			return $nominee->subclass =~ m/begin/ && $nominee->isa('Scribbler::ConditionalTile') && $Scribbler->clipboard->child(0)->isa('Scribbler::ConditionalBlock')
		},
		caninsert_v => sub{
			my $nominee = shift;
			my $first = $Scribbler->clipboard->begin;
			my $last = $Scribbler->clipboard->end;
			return 0 unless ref($first);
			return 0 if $first->isa('Scribbler::ConditionalBlock');
			return 0 if $first->isa('Scribbler::AndConditionalTile') && !($nominee->antecedent->subclass =~ m/if_begin|unless_begin|andif|andunless/);
			return 0 if $nominee->isa('Scribbler::AndConditionalTile') && !($last->isa('Scribbler::AndConditionalTile'));
			$nominee = $nominee->antecedent if ref($nominee) eq 'Scribbler::LoopTile' && $nominee->subclass eq 'loop_begin';
			my $depth = $nominee->loopDepth + $Scribbler->clipboardLoopDepth;
			my $counterdepth = $nominee->counterDepth + $Scribbler->clipboardCounterDepth;
			my $subcounterdepth = $nominee->subroutine->containedCounterDepth;
			my $totalcounters = $nominee->worksheet->counters - $subcounterdepth;
			$counterdepth = $subcounterdepth if $subcounterdepth > $counterdepth;
			return $depth <= $LOOP_DEPTH_LIMIT && $totalcounters + $counterdepth <= $LOOP_COUNTER_LIMIT
		},
		tip => 'Paste the clipboard item.'
	},
	
	move => {
		icon => 'move_fwd',
		onclick => sub{InsertNew('MotionTile')},
		tip => 'Insert a move command.'
	},
	
	leds => {
		icon => 'leds',
		onclick => sub{InsertNew('LedTile')},
		tip => 'Switch LEDs On/Off.' 
	},
	
	tune => {
		icon => 'tune',
		onclick => sub{InsertNew('SequencerTile')},
		tip => 'Insert a sound sequence.'
	},
	
  raise => {
  	icon => 'flag_green_raise',
  	onclick => sub{InsertNew('FlagActionTile')},
  	tip => 'Raise or lower a flag.'
  },
  
	pause => {
		icon => 'pause',
		onclick => sub{InsertNew('PauseTile')},
		tip => 'Insert a pause.'
	},
	
	query => {
		icon => 'binocs',
		onclick => sub{InsertNew('SensorReadTile')},
		tip => 'Observe a condition.'
	},
	
	compute => {
		icon => 'grinder',
		onclick => sub{InsertNew('ComputeTile')},
		tip => 'Perform a computation.'
	},
	
	if => {
		icon => 'if_else',
		caninsert_h => sub {
			my $nominee = shift;
			return $nominee->subclass =~ m/begin/ && $nominee->isa('Scribbler::ConditionalTile')
		},
		onclick => sub{
			if ($Cursor eq 'insert_v') {
				InsertNew('ConditionalArray')
			} else {
				InsertNew('ConditionalBlock')
			}
		},
		tip => 'Test a condition.'
	},
	
	andif => {
		icon => 'and_if',
		onclick=>sub{InsertNew('AndConditionalTile')},
		caninsert_v => sub {
			my $nominee = shift;
			return $nominee->antecedent->subclass =~ m/if_begin|unless_begin|andif|andunless/
		},
		tip => 'Require another condition.'
	},
	
	loop => {
		icon => 'loop',
		onclick => sub{InsertNew('Loop')},
		caninsert_v => sub{
			my $nominee = shift;
			return 0 if $nominee->isa('Scribbler::AndConditionalTile');
			my $depth = $nominee->loopDepth;
			$depth-- if ref($nominee) eq 'Scribbler::LoopTile' && $nominee->subclass eq 'loop_begin';
			return $depth < $LOOP_DEPTH_LIMIT
		},
		tip => 'Insert a program loop.'
	},
	
	exit => {
		icon => 'exit',
		onclick => sub{InsertNew('LoopExitTile')},
		caninsert_v => sub{
			my $nominee = shift;
			return 0 if $nominee->isa('Scribbler::AndConditionalTile');
			return $nominee->enclosing('Scribbler::Loop') && $nominee->antecedent->enclosing('Scribbler::Loop')
		},
		tip => 'Insert a loop exit.'
	},
	
	subroutine => {
		icon => 'sub',
		onselect => sub{
			InsertNew('Subroutine');
			$btnObjects{'edit'}->TurnOn
		},
		onmove => undef,
		tip => 'Make a new subroutine.'
	},
	
	return => {
		icon => 'return',
		onclick => sub{InsertNew('ReturnTile')},
		caninsert_v => sub {
			my $nominee = shift;
			return $nominee->subroutine->color ne 'green'
		},
		tip => 'Insert a subroutine return.'
	},
	
	call => {
		icon => 'call_red',
		caninsert_v => sub{
			my $nominee = shift;
			return 0 if $nominee->isa('Scribbler::AndConditionalTile');
			return $nominee->subroutine->canCall > 0
		},
		onclick => sub{InsertNew('CallTile')},
		tip => 'Call a subroutine.'
	},
	
	end => {
		icon => 'end',
		onclick => sub{InsertNew('EndTile')},
		tip => 'Insert a program end.'
	},
	
);

foreach my $object ($ObjectButtons->Values) {
	foreach my $default (keys %Default) {
		$object->{$default} = $Default{$default} unless exists $object->{$default}
	}
}

my $fraTop = $mw->Frame(-background => 'BLACK')->pack(-side => 'top', -fill => 'x');

my $fraScribbler = $fraTop->Frame(
	-relief => 'flat',
	-background => 'BLACK',
	-borderwidth => 1
)->pack(-side => 'left', -anchor => 'w');

$fraScribbler->Label(
	-image => $Scribbler->image('splash', 'scribbler'),
	-background => 'BLACK'
)->pack(-side => 'left', -anchor => 'w', -padx => 0);
	
my $fraCommands = $fraTop->Frame(
	-relief => 'flat',
	-background => $BG,
	-borderwidth => 3
)->pack(-side => 'left', -anchor => 'w');

my %btnCommands;

foreach ($MenuCommands->Keys) {
	my $entry = $MenuCommands->FETCH($_);
	$btnCommands{$_} = $fraCommands->ToggleButton(
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
		$_ eq 'help' ? (
			-pressimage => $Scribbler->button('query_pushon'),
			-offimage => $Scribbler->button('query_on')
		) : (
			-pressimage => $Scribbler->button($entry->{icon} . '_press'),
			-offimage => $Scribbler->button($entry->{icon} . '_release')
		),
		-command => [\&evtMenuCommandSelect, $entry]
	)->pack(-side => 'left', -pady => 0, -padx => 0, -anchor => 'w');
	$Scribbler->tooltip($btnCommands{$_}, $entry->{tip});
}
$btnCommands{help}->bind('<Button-3>' => \&evtToggletips);

my $fraObjects = $mw->Frame(
	-relief => 'flat',
	-background => $BG,
	-borderwidth => 1
)->pack(-side => 'left', -fill => 'y', -anchor => 'w');

my $fraHoriz;
my $column = 0;

foreach ($ObjectButtons->Keys) {
	my $entry = $ObjectButtons->FETCH($_);
	$fraHoriz = $fraObjects->Frame(-background => $fraObjects->cget('-background'))->pack(-anchor => 'w') if $column++ % $MenuColumns == 0;
	next if $_ eq 'null';
	$btnObjects{$_} = $fraHoriz->ToggleButton(
		-width => $BTN_SZ,
		-height => $BTN_SZ,
		-ontrigger => 'release',
		-latching => 1,
		-togglegroup => \%btnObjects,
		-onbackground => $BG,
		-offbackground => $BG,
		-onrelief => 'flat',
		-offrelief => 'flat',
		-pressrelief => 'flat',
		-borderwidth => 0,
		-cursor => 'hand2',
		-highlightthickness => 0,
		-index => $_,
		-offimage => $Scribbler->button($entry->{'icon'}.'_off'),
		-pressimage => $Scribbler->button($entry->{'icon'}.'_push'),
		-pressonimage => $Scribbler->button($entry->{'icon'}.'_pushon'),
		-onimage => $Scribbler->button($entry->{'icon'}.'_on'),
		-command => \&evtObjectMenuSelect
	)->pack(-side => 'left', -anchor => 'w', -pady => 0, -padx => 0);
	$Scribbler->tooltip($btnObjects{$_}, $entry->{tip})
}

$fraObjects->Label(
	-image => $Scribbler->image('splash', 'parallax'),
	-background => 'BLACK',
	-borderwidth => 0
)->pack(-side => 'bottom', -fill => 'y', -anchor => 's');

my $fraWorksheet = $mw->Frame(
	-relief => 'sunken',
	-borderwidth => 3
)->pack(-side => 'right', -expand => '1', -fill => 'both', -anchor => 'e');

my $scrWorksheet = $fraWorksheet->Scrolled('Canvas', 
	#-background => '#666676',
	-background => 'WHITE',
	-relief => 'flat',
	-borderwidth => 0,
	-scrollregion => [0, 0, $XEXTENT, $YEXTENT],
	-scrollbars => 'osoe',
	-xscrollincrement => $MINOR_GRID,
	-yscrollincrement => $MINOR_GRID
)->pack(-expand => '1', -fill => 'both', -anchor => 'e');

my $canWorksheet = $scrWorksheet->Subwidget('canvas');
$canWorksheet->CanvasBind('<Button-1>' => [\&evtWorksheetClick, 'onclick', Ev('x'), Ev('y')]);
$canWorksheet->CanvasBind('<Button-2>' => [\&evtWorksheetClick, 'oncenterclick', Ev('x'), Ev('y')]);
$canWorksheet->CanvasBind('<Button-3>' => [\&evtWorksheetClick, 'onrightclick', Ev('x'), Ev('y')]);
$canWorksheet->CanvasBind('<Shift-Button-1>' => [\&evtWorksheetClick, 'onshiftclick', Ev('x'), Ev('y')]);
$canWorksheet->CanvasBind('<Double-Button-1>' => [\&evtWorksheetClick, 'ondoubleclick', Ev('x'), Ev('y')]);
$canWorksheet->CanvasBind('<Motion>' => [\&evtWorksheetMotion, Ev('x'), Ev('y')]);
$canWorksheet->CanvasBind('<Leave>' => \&evtWorksheetLeave);
$canWorksheet->CanvasBind('<Configure>' => \&evtWorksheetResize);

if ($^O eq 'MSWin32') {
	#$canWorksheet->CanvasBind('full_only', '<MouseWheel>' => [\&evtMouseWheel, Ev('D')])
} else {
	#$canWorksheet->CanvasBind('<4>' => [\&evtMouseWheel, 1]);
	#$canWorksheet->CanvasBind('<5>' => [\&evtMouseWheel, -1])
}

$canWorksheet->createLine(0, 0, 0, 1, -tags => ['<lines>'], -fill => 'WHITE');

my %Cursor;

$Cursor{$_} = $canWorksheet->createImage(
	100, 100,
	-image => $Scribbler->cursor($_),
	-state => 'hidden',
	-tags => ['cursor', $_]
) foreach ('insert_h', 'insert_v');

$mw->DefineBitmap('shade' => 8, 2, pack('b8' x 2, '.1.1.1.1', '1.1.1.1.'));

$Scribbler->scrolled($scrWorksheet);
$Scribbler->size($XSLOTS, $YSLOTS);
$Scribbler->worksheet('New-1');
$Scribbler->worksheet->loadFile($ARGV[0]) if @ARGV;

$mw->deiconify;
$mw->raise;
$btnObjects{'edit'}->TurnOn;
$mw->MainLoop;

sub evtToggletips {
	my $self = shift;
	my $tips = $Scribbler->tooltipEnable(undef, !$Scribbler->tooltipEnable);
	$self->configure(
		-pressimage => $Scribbler->button('query_' . ($tips ? 'pushon' : 'push')),
		-offimage => $Scribbler->button('query_' . ($tips ? 'on' : 'off'))
	)
}

sub evtMenuCommandSelect {
	my $entry = shift;
	unless ($Zoom == 1) {
		Rescale(0, 0, 1);
		$btnObjects{'edit'}->TurnOn
	}
	&{$entry->{onselect}}
}

sub evtObjectMenuSelect {
	my ($on, $which) = @_;
	return unless $on;
	$Scribbler->worksheet->selectRemoveAll;
	if ($which eq 'zoom') {
		$canWorksheet->itemconfigure('cursor', -state => 'hidden');
		Refit() if $Zoom == 1;
	} else {
		Rescale(0, 0, 1) unless $Zoom == 1;
	}
	my $object = $ObjectButtons->FETCH($which);
	$canWorksheet->configure(-cursor => $object->{pointer});
	$PrevIndex = $CurrIndex;
	$CurrIndex = $which;
	&{$object->{'onselect'}} if $object->{'onselect'}
}

sub evtWorksheetResize {
	Refit() if $CurrIndex eq 'zoom';
}

sub evtWorksheetClick {
	my ($self, $event, $x, $y) = @_;
	($x, $y) = ($canWorksheet->canvasx($x), $canWorksheet->canvasy($y));
	my $object = $ObjectButtons->FETCH($CurrIndex);
	if (my $handler = $object->{$event}) {
		my @args;
		if (ref($handler) eq 'ARRAY') {
			@args = @$handler[1 .. @$handler - 1];
			$handler = $handler->[0]
		}
		&$handler($Scribbler, $x, $y, @args);
		$self->itemconfigure('cursor', -state => 'hidden')
	} 
}

sub ForceEdit {
	my ($scribbler, $x, $y) = @_;
	my $worksheet = $scribbler->worksheet;
	$btnObjects{edit}->TurnOn;
	MoveSelect($scribbler, $x, $y);
	if ($worksheet->nominateTile) {
		$worksheet->selectNominee;
		#EditSelected($worksheet)
	}
}

sub EditNominee {
	my ($scribbler, $x, $y) = @_;
	my $worksheet = $scribbler->worksheet;
	$worksheet->selectNominee unless $worksheet->selected;
	EditSelected($worksheet);
}

sub EditSelected {
	my $worksheet = shift;
	$worksheet->editSelected =~ m/cut|copy/ and $btnObjects{paste}->TurnOn
}	

sub SelectItem {
	my ($scribbler, $x, $y) = @_;
	my $worksheet = $scribbler->worksheet;
	if ($worksheet->nominateTile) {
		$worksheet->selectNominee
	} else {
		$worksheet->selectRemoveAll
	}
}

sub SelectToItem {
	my ($scribbler, $x, $y) = @_;
	$scribbler->worksheet->selectToNominee;
}

sub InsertNew {
	$Scribbler->worksheet->insertNew(@_)
}

sub ZoomIn {
	my ($scribbler, $x, $y) = @_;
	my $zoom = $Zoom;
	$btnObjects{$PrevIndex}->TurnOn;
	Rescale(0, 0, 1);
	$canWorksheet->xviewMoveto(int($x / $zoom / $MAJOR_XGRID) * $MAJOR_XGRID / $scribbler->xExtent);
	$canWorksheet->yviewMoveto(int($y / $zoom / $MAJOR_YGRID) * $MAJOR_YGRID / $scribbler->yExtent);
}

sub Query {
	my ($scribbler, $x, $y, $obj) = @_;
	$obj = defined $obj ? $obj : ($scribbler->worksheet->selected)[0] || $scribbler->worksheet->nominateTile || $scribbler->worksheet;
	$obj = $obj->parent if $obj->subclass =~ m/_begin/;
	$obj->query;
}

sub evtMouseWheel {
	return if $CurrIndex eq 'zoom';
	my $self = shift;
	my $dy = shift;
	$dy = $dy < 0 ? 5 * $PAN_AMT : -5 * $PAN_AMT;
	$scrWorksheet->yviewScroll($dy, 'units') unless defined $AutoPanY || defined $AutoDelayY;
}

sub evtWorksheetLeave {
	my ($self, $x, $y) = @_;
	$mw->afterCancel($AutoPanX) if $AutoPanX;
	$mw->afterCancel($AutoDelayX) if $AutoDelayX;
	$mw->afterCancel($AutoPanY) if $AutoPanY;
	$mw->afterCancel($AutoDelayY) if $AutoDelayY;
	($AutoPanX, $AutoDelayX, $AutoPanY, $AutoDelayY) = undef;
	$self->configure(-cursor => $ObjectButtons->FETCH($CurrIndex)->{pointer});
	$self->itemconfigure('cursor', -state => 'hidden');
	($CursorX, $CursorY) = (-1000, -1000);
}		 

sub evtWorksheetMotion {
	my ($self, $x, $y) = @_;
	my $worksheet = $Scribbler->worksheet;
	my $object = $ObjectButtons->FETCH($CurrIndex);
	if ($object->{autopan}) {
		my ($dx, $dy);
		my $newpointer = 0;
		my $panningX = $AutoPanX || $AutoDelayX;
		my $panningY = $AutoPanY || $AutoDelayY;
		if ($dx = $x < 10 ? -$PAN_AMT : $x > $self->width - 10 ? $PAN_AMT : 0) {
			unless ($panningX) {
				$AutoDelayX = $mw->after($PAN_DELAY, sub{undef $AutoDelayX});
				$AutoPanX = $mw->repeat($PAN_REPEAT, sub{$self->xviewScroll($dx, 'units') unless $AutoDelayX});
				$newpointer = 2
			}
		} elsif ($panningX) {
			$mw->afterCancel($AutoPanX) if $AutoPanX;
			$mw->afterCancel($AutoDelayX) if $AutoDelayX;
			($AutoPanX, $AutoDelayX) = undef;
			$newpointer = 1
		}
		if ($dy = $y < 10 ? -$PAN_AMT : $y > $self->height - 10 ? $PAN_AMT : 0) {
			unless ($panningY) {
				$AutoDelayY = $mw->after($PAN_DELAY, sub{undef $AutoDelayY});
				$AutoPanY = $mw->repeat($PAN_REPEAT, sub{$self->yviewScroll($dy, 'units') unless $AutoDelayY});
				$newpointer = 2
			}
		} elsif ($panningY) {
			$mw->afterCancel($AutoPanY) if $AutoPanY;
			$mw->afterCancel($AutoDelayY) if $AutoDelayY;
			($AutoPanY, $AutoDelayY) = undef;
			$newpointer = 1
		}
		if ($newpointer) {
			if ($newpointer == 2) {
				if ($dx < 0) {
					$newpointer = $dy < 0 ? 'top_left_corner' : $dy > 0 ? 'bottom_left_corner' : 'left_side'
				} elsif ($dx > 0) {
					$newpointer = $dy < 0 ? 'top_right_corner' : $dy > 0 ? 'bottom_right_corner' : 'right_side'
				} else {
					$newpointer = $dy < 0 ? 'top_side' : $dy > 0 ? 'bottom_side' : $ObjectButtons->FETCH($CurrIndex)->{pointer}
				}
			} else {
				$newpointer = $ObjectButtons->FETCH($CurrIndex)->{pointer}
			}
			$self->configure(-cursor => $newpointer)
		}
	}
	&{$object->{onmove}}($self, $self->canvasx($x) - $MINOR_GRID, $self->canvasy($y) - $MINOR_GRID) if $object->{onmove}
}

sub MoveInsert {
	my ($self, $x, $y) = @_;
	my $object = $ObjectButtons->FETCH($CurrIndex);
	my $worksheet = $Scribbler->worksheet;
	my $newcursor = 0;
	my $centerx = abs($x % $MAJOR_XGRID - $XC);
	my $borderx = $XC - $centerx;
	my $centery = abs($y % $MAJOR_YGRID - $YC);
	my $bordery = $YC - $centery;
	if ($bordery > $HYST && $borderx < $HYST) {
		$Cursor = 'insert_h';
		$CursorX = int($x / $MAJOR_XGRID + 0.5) * $MAJOR_XGRID;
		$CursorY = $y - $y % $MAJOR_YGRID + $YC;
		$newcursor = 1
	} elsif ($borderx > $HYST && $bordery < $HYST) {
		$Cursor = 'insert_v';
		$CursorX = $x - $x % $MAJOR_XGRID + $XC;
		$CursorY = int($y / $MAJOR_YGRID + 0.5) * $MAJOR_YGRID;
		$newcursor = 1;
	}	elsif (abs($x - $CursorX) > $MAJOR_XGRID - $HYST || abs($y - $CursorY) > $MAJOR_YGRID - $HYST) {
		if ($Cursor eq 'insert_h') {
			$CursorX = int($x / $MAJOR_XGRID + 0.5) * $MAJOR_XGRID;
			$CursorY = $y - $y % $MAJOR_YGRID + $YC
		} else {
			$CursorX = $x - $x % $MAJOR_XGRID + $XC;
			$CursorY = int($y / $MAJOR_YGRID + 0.5) * $MAJOR_YGRID
		}			
		$newcursor = 1
	}
	if ($newcursor) {
		$self->coords($Cursor, $CursorX + $MINOR_GRID, $CursorY + $MINOR_GRID);
		my $ix = Scribbler::floor(($CursorX - 1) / $MAJOR_XGRID);
		my $iy = Scribbler::floor(($CursorY - 1) / $MAJOR_YGRID);
		my ($first, $second, $state);
		if ($Cursor eq 'insert_h') {
			$self->itemconfigure($Cursor{'insert_v'}, -state => 'hidden');
			$state = (
				$CursorX and $CursorY and
				$second = $worksheet->grid($ix + 1, $iy) and
				$first = $second->parent->antecedent->begin and
				($worksheet->grid($first))[1] == $iy and
				$first->subroutine eq $second->subroutine and
				&{$object->{caninsert_h}}($second) and
				$worksheet->nominateTile($second)
			) ? 'normal' : 'hidden';
		} elsif ($Cursor eq 'insert_v') {
			$self->itemconfigure($Cursor{'insert_h'}, -state => 'hidden');
			$state = (
				$CursorX and $CursorY and
				$second = $worksheet->grid($ix, $iy + 1) and
				$first = $second->antecedentTile and
				($worksheet->grid($first))[0] == $ix and
				&{$object->{caninsert_v}}($second) and
				$worksheet->nominateTile($second)
			) ? 'normal' : 'hidden';
		} else {
			$state = 'hidden'
		}
		$state = 'hidden' if $AutoPanX || $AutoPanY;
		$worksheet->nominateRemove if $state eq 'hidden';
		$self->itemconfigure($Cursor{$Cursor}, -state => $state)
	}			
}

sub MoveSelect {
	my ($self, $x, $y) = @_;
	my $worksheet = $Scribbler->worksheet;
	my $ix = Scribbler::floor(($x - 1) / $MAJOR_XGRID);
	my $iy = Scribbler::floor(($y - 1) / $MAJOR_YGRID);
	my $pointer = $ObjectButtons->FETCH($CurrIndex)->{'pointer'};
	if ($ix != $CursorX || $iy != $CursorY) {
		($CursorX, $CursorY) = ($ix, $iy);
		if (my $tile = $worksheet->grid($ix, $iy)) {
			my $subclass = $tile->subclass || '';
			#$self->configure(-cursor => $subclass =~ m/_end/ ? 'based_arrow_up' : $subclass eq 'block' ? 'based_arrow_down' : 'hand2');
			$self->configure(-cursor => 'hand2');
			$worksheet->nominateTile($tile)
		} else {
			$self->configure(-cursor => $ObjectButtons->FETCH($CurrIndex)->{pointer});
			$worksheet->nominateRemove
		}
	}
}

sub Refit {
	my $xscale = ($canWorksheet->Width - 4) / $Scribbler->xExtent;
	my $yscale = ($canWorksheet->Height - 4) / $Scribbler->yExtent;
	Rescale(0, 0, $xscale < $yscale ? $xscale : $yscale)
}		

sub Rescale {
	my ($locx, $locy, $scale) = @_;
	my $worksheet = $Scribbler->worksheet;
	if ($scale == 1) {
		$worksheet->showFull;
		unless ($Zoom == 1) {
			$canWorksheet->scale("all", $locx, $locy, 1 / $Zoom, 1 / $Zoom);
			$Zoom = 1;
			$scrWorksheet->configure(-scrollregion => [0, 0, $Scribbler->xExtent, $Scribbler->yExtent])
		}
	} else {
		$worksheet->showZoom;
		my $adj = $scale / $Zoom;
		$Zoom = $scale;
		$canWorksheet->scale("all", $locx, $locy, $adj, $adj);
		$scrWorksheet->configure(-scrollregion => [0, 0, $Zoom * $Scribbler->xExtent, $Zoom * $Scribbler->yExtent])
	}
}

sub PowerDown {
	if (my @dirty = grep {$_->dirty} $Scribbler->worksheets) {
		foreach (@dirty) {
			return unless $_->querySave($Scribbler->translate('Scribbler is shutting down') . '...') 
		}
	}
	$Scribbler->saveInit;
	exit
}
