use strict;
#use lib '/jobs/perl/parallax/s2'; #Must comment out for perl2exe.
use Carp;
use Tk;
use Tk::PNG;
use Tk::ToggleButton;
use Tk::Photo;
use Tk::Canvas;
use Tk::Icon;
use Win32::SerialPort;
use File::Spec;
use Archive::Zip;
use MIME::Base64;
use Win32;
use Win32::Process;
use Time::HiRes qw/sleep/;

require "utf8_heavy.pl";
require "unicore/lib/SpacePer.pl";
require "unicore/To/Lower.pl";
require "unicore/To/Upper.pl";
require "unicore/To/Fold.pl";
require "unicore/lib/Digit.pl";
require "unicore/lib/Word.pl";
require "Encode/Unicode.pm";

#perl2exe_bundle "/jobs/perl/parallax/s2/monitor.zip"
#perl2exe_bundle "/jobs/perl/parallax/s2/monitor.txt"

my $other_objects = 1;

my $self = $0;
$self =~ s/\\/\//g;
$self =~ s/(.*)\/[^\/]*/$1/;
my $INIT_DIR = File::Spec->canonpath($self);
my $TEMP_DIR = ($ENV{TEMP} || $ENV{TMP} || $ENV{WINDIR} || '/tmp');
if (-e (my $p2xtemp = $TEMP_DIR . "/p2xtmp-$$")) {
	$TEMP_DIR = $p2xtemp
}
#print "$INIT_DIR\n";
#print "$TEMP_DIR\n";
my $FILE_DIR = (-e "$TEMP_DIR/monitor.txt") ? $TEMP_DIR : $INIT_DIR;
#print "$FILE_DIR\n";
my $IMG_DIR = File::Spec->canonpath("./images");
chdir $INIT_DIR;

my $Code;

if (open(SPN, "<$FILE_DIR/monitor.txt")) {
	while (<SPN>) {
		$Code .= $_
	}
	close SPN
} else {
	PowerDown('Missing monitor.txt file.')
}

my %Init;

if (open(INI, "<$INIT_DIR/s2.ini")) {
	while (<INI>) {
		s/\n\r//g;
		$Init{$1} = $2 if /(\w+)\s*=\s*(.*)/;
	}
	close INI;
	if (exists $Init{line_thld}) {
		my $newval = $Init{line_thld};
		$Code =~ s/(LINE_THLD\s*=\s*)\d+/$1$newval/
	}
	if (exists $Init{bar_thld}) {
		my $newval = $Init{bar_thld};
		$Code =~ s/(BAR_THLD\s*=\s*)\d+/$1$newval/
	}
	if (exists $Init{obstacle_thld}) {
		my $newval = $Init{obstacle_thld};
		$Code =~ s/(OBSTACLE_THLD\s*=\s*)\d+/$1$newval/
	}
} else {
	PowerDown('Missing s2.ini file.')
}
my $outfile = Win32::GetShortPathName($TEMP_DIR) . '\monitor.spin';
if (open SPN, ">$outfile") {
	print SPN $Code;
	close SPN
} else {
	PowerDown('Cannot write monitor.spin to temp directory.')
}

PowerDown('Missing propellent.exe') unless $Init{loader} && $Init{loader} =~ m/propellent.exe/ && -e $Init{loader};

my $Doors = 0;

my $mw = Tk::MainWindow->new(-width => 720, -height => 540, -background => 'BLACK', -title => 'Scribbler Sensor Observation Deck');
$mw->minsize(800,355);
$mw->resizable(0,0);
$mw->protocol('WM_DELETE_WINDOW' => \&PowerDown);
$mw->setIcon(-file => "$IMG_DIR/win_binocs.ico");

my %ImageData;
my @Intensity;
my $limit;

foreach (0 .. 255) {
	my $value = atan2($_ - 128, 64);
	$limit = abs($value) unless $_;
	$Intensity[$_] = int(($value / $limit + 1) * 127.5 + 0.5);
	#printf "%3.1d %3.1d\n", $_, $value
}

my $phone = rand() > 0.2 && $other_objects;
my $soccer = rand() > 0.997 && $other_objects;
my $book = rand() > 0.9 && $other_objects;
my $glass = rand() > 0.66 && $other_objects;
my $coffee = rand() > 0.5 && !$glass && $other_objects;
my $man = rand() > 0.75 && $other_objects;

my $State = 0;

%ImageData = (
 	background => [2, 2, 'nw'],
 	book => [801, 2,'ne'],
 	phone => [177, 357, 'sw'],
 	glass => [474, 357, 'sw'],
 	coffee => [474, 357, 'sw'],
 	soccer => [184, 357, 'sw'],
 	man => [530, 400, 'sw'],
 	port_on => [2, 2, 'nw'],
 	stbd_on => [801, 2, 'ne'],
 	stbd_on_book => [801, 2, 'ne'],
 	stbd_line => [402, 357, 'sw'],
 	stbd_line_glass => [402, 357, 'sw'],
 	port_line => [402, 357, 'se'],
 	wall_none => [245, 160, 'nw'],
 	line_none => [559, 160, 'ne'],
 	port_door => [550, 2, 'ne'],
 	stbd_door => [250, 2, 'nw'],
 	door_leds_0 => [430, 180, 'w'],
 	door_black => [544, 180, 'w']
);

my %Image;

my $zip = Archive::Zip->new("$FILE_DIR/monitor.zip");
foreach ($zip->memberNames) {
	m/([a-z_\d]+)\.(png|gif)$/;
	#print "$1\n";
	$Image{$1} = $mw->Photo(-data => encode_base64($zip->contents($_)))
}

my $canScribbler = $mw->Canvas(
	-width => 800,
	-height => 355,
	-background => 'BLACK'
)->pack;

$canScribbler->createRectangle(240, 15, 290, 65, -fill => 'GRAY', -tag => 'light_0');
$canScribbler->createRectangle(377, 20, 427, 70, -fill => 'WHITE', -tag => 'light_1');
$canScribbler->createRectangle(514, 15, 564, 65, -fill => 'GRAY', -tag => 'light_2');
$canScribbler->createRectangle(387, 115, 417, 145, -fill => 'RED', -tag => 'obstacle', -state => 'hidden');

DrawImage('background', 'background');
DrawImage('phone', 'phone') if $phone;
DrawImage('soccer', 'soccer') if $soccer;
DrawImage('book', 'book') if $book;
DrawImage('glass', 'glass') if $glass;
DrawImage('coffee', 'coffee') if $coffee;
DrawImage($book ? 'stbd_on_book' : 'stbd_on', 'stbd_on');
DrawImage('port_on', 'port_on');
DrawImage('port_line', 'port_line');
DrawImage($glass ? 'stbd_line_glass' : 'stbd_line', 'stbd_line');
DrawImage('wall_none', 'wall');
DrawImage('line_none', 'line');

foreach (0 .. 2) {
	$canScribbler->createRectangle(
		347 + 40 * $_, 220, 377 + 40 * $_, 220, 
		-outline => 'GREEN',
		-fill => '#00C000',
		-width => 2,
		-tags => "bar_$_",
		-width => 0
	);
	$canScribbler->createText(
		374 + 40 * $_, 240,
		-text => '000',
		-justify => 'right',
		-anchor => 'se',
		-font => 'system',
		-fill => '#00C000',
		-tags => "text_$_"
	)
}	

$canScribbler->createRectangle(220, 140, 585, 245, -fill => 'BLACK', -tag => 'nodata');

DrawImage('man', 'man') if $man;
DrawImage('port_door', 'port_door');
DrawImage('stbd_door', 'stbd_door');
DrawImage('door_leds_0', 'door_leds');
DrawImage('door_black', 'door_color');
$mw->update;

my $status = getrun(qq("$Init{loader}" /lib "$INIT_DIR/editor" /eeprom /gui off "$outfile"), "Uploading...");

#print $status;

$canScribbler->itemconfigure('door_leds', -state => 'hidden');

ErrorExit() unless ($status =~ m/EVT:505/);
	
$status =~ m/EVT:505.+(COM\d+)\./;
my $PortName = $1;

my $Port;

unless ($Port = new Win32::SerialPort("\\\\.\\" . $PortName)
	and	$Port->baudrate(9600)
	and $Port->parity('none')
	and $Port->databits(8)
	and $Port->stopbits(2)
	and $Port->handshake('none')
	and $Port->buffers(4096,4096)
	and $Port->binary(1)
	and $Port->dtr_active(0)
	and $Port->write_settings)
{
	#print $^E;
	ErrorExit()
}

$Port->dtr_active(0);

$canScribbler->itemconfigure('door_color', -image => $Image{door_green});
$mw->update;
sleep 1;

my $Stream;
my $Obstacles = 0;
my @Light = my @Same = (0) x 3;
my $NoData = 20;

$mw->repeat(20, \&Update);

$mw->MainLoop();

sub DrawImage {
	my $key = shift;
	my $tag = shift;
	my @data = @{$ImageData{$key}};
	$canScribbler->createImage(
		$data[0], $data[1],
		-anchor => $data[2],
		-image => $Image{$key},
		-tags => $tag
	)
}

sub Update {
	my (undef, $n, undef, $err) = ($Port->status);
	if ($err) {
		#print "$err\n";
		$Port->reset_error
	}
	if ($n) {
		my ($data, $nxt);
		$Stream .= $Port->input;
		while ($Stream =~ m/<([A-F0-9]{7})>/osg) {
			$data = $1;
			$nxt = pos($Stream)
		}
		if (defined $nxt) {
			$Stream = substr($Stream, $nxt);
			undef $nxt;
			foreach (0 .. 2) {
				my $light = hex(substr($data, $_ * 2, 2));
				if (abs($light - $Light[$_]) <= 1) {
					if ($Same[$_]++ > 10) {
						$Same[$_] = 0;
						$Light[$_] = $light
					}
				} else {
					$Same[$_] = 0;
					$Light[$_] = $light
				}
				my $inten = $Intensity[$Light[$_]];
				$inten = $inten < 0 ? 0 : $inten > 255 ? 255 : $inten;
				$canScribbler->itemconfigure("light_$_", -fill => sprintf("#%6.6X" , $inten * 0x010101));
				$canScribbler->coords("bar_$_", 347 + 40 * $_, 220, 377 + 40 * $_, 220 - $Light[$_] / 4);
				$canScribbler->itemconfigure("text_$_", -text => $Light[$_])
			}
			my $flags = hex(substr($data, 6, 1));
			$canScribbler->itemconfigure('port_line', -state => $flags & 8 ? 'hidden' : 'normal');
			$canScribbler->itemconfigure('stbd_line', -state => $flags & 4 ? 'hidden' : 'normal');
			$canScribbler->itemconfigure('line', -image => $Image{(qw/line_both line_port line_stbd line_none/)[($flags >> 2) & 3]});
			$Obstacles = $flags & 3;
			if ($NoData >= 20) {
				$canScribbler->itemconfigure('nodata', -state => 'hidden')
			}
			$NoData = 0
		}				
	}
	if (++$NoData == 20) {
		$canScribbler->itemconfigure('nodata', -state => 'normal')
	}
	$State = ($State + 1) % 20;
	if ($State == 0) {
		$canScribbler->itemconfigure('port_on', -state => 'normal');
		$canScribbler->itemconfigure('obstacle', -state => 'normal') if $Obstacles & 2;
		DisplayObstacles()
	} elsif ($State == 2) {
		$canScribbler->itemconfigure('port_on', -state => 'hidden');
		$canScribbler->itemconfigure('obstacle', -state => 'hidden')
	} elsif ($State == 10) {
		$canScribbler->itemconfigure('stbd_on', -state => 'normal');
		$canScribbler->itemconfigure('obstacle', -state => 'normal') if $Obstacles & 1;
		DisplayObstacles()
	} elsif ($State == 12) {
		$canScribbler->itemconfigure('stbd_on', -state => 'hidden');
		$canScribbler->itemconfigure('obstacle', -state => 'hidden')
	}
	if ($Doors < 550) {
		$Doors += 50;
		$canScribbler->move('port_door', -50, 0);
		$canScribbler->move('stbd_door', 50, 0);
		$canScribbler->move('door_color', 50, 0)
	}
}

sub DisplayObstacles {
	$canScribbler->itemconfigure('wall', -image => $Image{(qw/wall_none wall_stbd wall_port wall_both/)[$Obstacles]})
}

sub getrun {
	my $command = shift;
	my $outfile = "$TEMP_DIR/scribbler.out";
	if (run("$command > $outfile")) {
		open STAT, "<$outfile" or return "ERR:000-Can't open temporary file.";
		local $/ = undef;
		my $stat = <STAT>;
		close STAT;
		unlink $outfile;
		return $stat
	} else {
		return "ERR:000-Can't create process."
	}
}

sub run {
	my $cmd = shift;
	$cmd = Win32::GetShortPathName($INIT_DIR) . "\\$cmd";
  my $shell = $ENV{ComSpec};
	if (Win32::Process::Create(my $process, $shell, "$shell /c $cmd", 0, NORMAL_PRIORITY_CLASS | CREATE_NO_WINDOW, '.')) {
		my $frame = 0;
		until ($process->Wait(50)) {
			$frame = ($frame + 1) % 5;
			$canScribbler->itemconfigure('door_leds', -image => $Image{"door_leds_$frame"});
			$mw->update
		}
	  return 1 
  } else {
  	return 0
  }
}

sub ErrorExit {
	foreach (0 .. 2) {
		sleep 0.25;
		$canScribbler->itemconfigure('door_color', -image => $Image{door_black});
		$mw->update;
		sleep 0.25;
		$canScribbler->itemconfigure('door_color', -image => $Image{door_red});
		$mw->update
	}
	sleep 2;		
	PowerDown()
}

sub PowerDown {
	print "$_[0]\n" if $_[0];
	$Port->close if $Port;
	undef $Port;
	unlink $outfile if -e $outfile;
	exit
}



