package Scribbler::Constants;
use strict;
use File::Spec;
require Exporter;
our @ISA = ('Exporter');

our @EXPORT = qw(
	$VERSION $MINOR_GRID $MAJOR_XGRID $MAJOR_YGRID $FS $XSLOTS $YSLOTS $XMAX $YMAX
	$XEXTENT $YEXTENT $ARROW $LINE_WIDTH $ACTIVE_LINE_COLOR $INACTIVE_LINE_COLOR $PAN_DELAY $PAN_REPEAT $PAN_AMT $TILE_PAD
	$X0 $XC $X1 $Y0 $YC $Y1 $BTN_SZ $BG $IMG_DIR $INIT_DIR $TEMP_DIR $USER_DIR $HYST $MINUS @COLORS @FLAG_COLORS $PLSMNS $MULT
	$ROOT_COLOR $ACTIVE $INACTIVE $SUB_DEPTH_LIMIT $LOOP_DEPTH_LIMIT $LOOP_COUNTER_LIMIT $MEMORY_LIMIT $TILE_XINDENT
	$TILE_YINDENT $LOOP_PRIORITY $SUB_PRIORITY $SOUND_LATENCY $CODE_INDENT_INCREMENT $FIRST_ROM_ADDR
	$SCRIBBLER_BLUE $LIGHT_SCRIBBLER_BLUE $DARK_SCRIBBLER_BLUE $SLIDER_WIDTH $SLIDER_LENGTH
);

our $VERSION = '1.1';

my $self = $0;
$self =~ s/\\/\//g;
$self =~ s/(.*)\/[^\/]*/$1/;

our $INIT_DIR = File::Spec->canonpath($self);
our $IMG_DIR = File::Spec->canonpath("./images");
our $TEMP_DIR = File::Spec->tmpdir;
our $USER_DIR = $ENV{USERPROFILE};
	if (-d "$USER_DIR\\My Documents") {
		$USER_DIR .= '\My Documents'
	} elsif (-d "$USER_DIR\\Documents") {
		$USER_DIR .= '\Documents'
	}		

our $MINOR_GRID = 9;
our $MAJOR_XGRID = 12 * $MINOR_GRID;
our $MAJOR_YGRID = 8 * $MINOR_GRID;
our $FS = $MINOR_GRID / 9;
our $XSLOTS = 40;
our $YSLOTS = 50;
our $XMAX = $XSLOTS * $MAJOR_XGRID;
our $YMAX = $YSLOTS * $MAJOR_YGRID;
our $XEXTENT = $XMAX + 2 * $MINOR_GRID;
our $YEXTENT = $YMAX + 2 * $MINOR_GRID;
our $ARROW = [10, 10, 6];
our $LINE_WIDTH = 6;
our $ACTIVE_LINE_COLOR = 'BLACK';
our $INACTIVE_LINE_COLOR = '#CCCCEE';
our $TILE_XINDENT = 8 / $MAJOR_XGRID;
our $TILE_YINDENT = 8 / $MAJOR_YGRID;
our $PAN_DELAY = 500;
our $PAN_REPEAT = 50;
our $PAN_AMT = 2;
our $TILE_PAD = 3;
our ($X0, $X1) = ($TILE_PAD, $MAJOR_XGRID - $TILE_PAD);
our ($Y0, $Y1) = ($TILE_PAD, $MAJOR_YGRID - $TILE_PAD);
our ($XC, $YC) = (int(($X0 + $X1) / 2), int(($Y0 + $Y1) / 2));
our $BTN_SZ = 49;
our $BG = 'BLACK';
our $HYST = int($MINOR_GRID * 1.25);
our $MINUS = '­';
our $PLSMNS = "\xb1";
our $MULT = "\xd7";
our @COLORS = qw/green yellow orange red magenta purple blue cyan/;
our @FLAG_COLORS = qw/green yellow orange red magenta purple blue/;
our $ROOT_COLOR = 'green';
our $ACTIVE = 'on';
our $INACTIVE = 'off';
our $SUB_DEPTH_LIMIT = 3;
our $LOOP_DEPTH_LIMIT = 64;
our $LOOP_COUNTER_LIMIT = 6;
our $MEMORY_LIMIT = 3;
our $LOOP_PRIORITY = 0.4;
our $SUB_PRIORITY = 0.2;
our $SOUND_LATENCY = 10;
our $CODE_INDENT_INCREMENT = 2;
our $FIRST_ROM_ADDR = 4;
our $SCRIBBLER_BLUE = '#0593E2';
our $LIGHT_SCRIBBLER_BLUE = '#06A6FF';
our $DARK_SCRIBBLER_BLUE = '#0475B5';
our $SLIDER_WIDTH = 15;
our $SLIDER_LENGTH = 15;

1;
