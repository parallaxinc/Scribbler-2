package Scribbler;
use strict;
use Carp;
use Tk;
use Tk::Radiobutton;
use Tk::Icon;
use Scribbler::Constants;
use Scribbler::SoundLibrary;
use File::Spec qw/canonpath catfile/;
use base qw/Scribbler::Atom/;
use Win32;
use Win32::Process;

$VERSION = '1.5';

sub new {
 	my ($invocant, $mw) = @_;
 	my $class = ref($invocant) || $invocant;
 	my $self = Scribbler::Atom::new($class);
	$self->mainwindow($mw);
	$self->{tooltip} = {};
	$self->{random} = 0;
	$self->{tooltips} = 1;
	$self->{size} = [0, 0];
	$self->{userdir} = "$USER_DIR\\S2 Programs";
	$self->{utf16} = 0;
	unless (-d $self->{userdir}) {
		unless (mkdir $self->{userdir}) {
			$self->{userdir} = ''
		}
	}
	if (open(CODE, "<$INIT_DIR/include.spin")) {
		my $section;
		while (<CODE>) {
			if (m/'%%(.+):(.*)/) {
				my $key = lc $1;
				my $value = $2;
				if ($key eq 'section') {
					$section = lc $value;
					$self->{code}->{$section} = ''
				} elsif ($key eq 'heading') {
					$self->{code}->{$section} .= $self->codeHeader($value) . "\n"
				} elsif ($key eq 'requires') {
					push @{$self->{required}->{$section}} , lc $value
				}
			} else {
				$self->{code}->{$section} .= $_ if $section
			}
		}
		close CODE
	}
	chdir $INIT_DIR;
	foreach my $family (qw/icon button tile cursor lcd counter splash/) {
		foreach (<$IMG_DIR/$family\_*.gif>) {
			m/$family\_(.+)\.gif/;
			$self->{images}->{$family}->{$1} = $mw->Photo(-file => $_)
		}
	}
	$self->{sounds} = Scribbler::SoundLibrary->new;
	$self->{sounds}->readAbcFile("$INIT_DIR/soundlib.abc");
	$self->{fonts}->{'smallfont'} = $mw->fontCreate('SmallFont', -family => 'Helvetica', -size => 9, -weight => 'bold');
	$self->{fonts}->{'tilefont'} = $mw->fontCreate('TileFont', -family => 'Helvetica', -size => int(10 * $FS), -weight => 'bold');
	$self->{fonts}->{'dialogfont'} = $mw->fontCreate('DialogFont', -family => 'Helvetica', -size => int(9 * $FS), -weight => 'bold');
	$self->{fonts}->{'bigfont'} = $mw->fontCreate('BigFont', -family => 'Helvetica', -size => int(16 * $FS), -weight => 'bold');
	$self->{fonts}->{'fixedfont'} = $mw->fontCreate('FixedFont', -family => 'Courier', -size => int(14 * $FS), -weight => 'bold');
	$self->{clipboard} = Scribbler::AtomBlock->new($self);
	if (open(INI, "<$INIT_DIR/S2.ini")) {
		while (<INI>) {
			s/\n\r//g;
			$self->{init}->{$1} = $2 if /(\w+)\s*=\s*(.*)/;
		}
		close INI;
		delete $self->{init}->{lasterror};
		if (exists $self->{init}->{line_thld}) {
			my $newval = $self->{init}->{line_thld};
			$newval = 1 if $newval < 1;
			$newval = 255 if $newval > 255;
			$self->{init}->{line_thld} = $newval;
			$self->{code}->{preamble} =~ s/(LINE_THLD\s*=\s*)\d+/$1$newval/
		}
		if (exists $self->{init}->{bar_thld}) {
			my $newval = $self->{init}->{bar_thld};
			$newval = 1 if $newval < 1;
			$newval = 255 if $newval > 255;
			$self->{init}->{bar_thld} = $newval;
			$self->{code}->{preamble} =~ s/(BAR_THLD\s*=\s*)\d+/$1$newval/
		}
		if (exists $self->{init}->{obstacle_thld}) {
			my $newval = $self->{init}->{obstacle_thld};
			$newval = 1 if $newval < 1;
			$newval = 255 if $newval > 255;
			$self->{init}->{obstacle_thld} = $newval;
			$self->{code}->{preamble} =~ s/(OBSTACLE_THLD\s*=\s*)\d+/$1$newval/
		}
		if (exists $self->{init}->{spkr_vol}) {
			my $newval = $self->{init}->{spkr_vol};
			$newval = 0 if $newval < 0;
			$newval = 100 if $newval > 100;
			$self->{init}->{spkr_vol} = $newval;
			$self->{code}->{preamble} =~ s/(SPKR_VOL\s*=\s*)\d+/$1$newval/
		}	
	}
	chdir $INIT_DIR;
	unless ($self->init('language')) {
		my @languages = (['<< Click here for English', 'english']);
		$self->init(toolfont => undef);
		foreach my $dict (<*.dic>) {
			my $lang = ($dict =~ m/(.+)\.dic$/)[0];
			if (open DIC, "<$dict") {
				my $line = <DIC>;
				if ($line =~ m/^\xff\xfe/) {
					close DIC;
					open DIC, "<:encoding(utf16)", $dict;
					$line = <DIC>
				}
				$line =~ s/[\n\r]//g;
				if ($line =~ m/\s*Language\s*=\s*(.*\S)\s*/) {
					push @languages, ["<< $1", $lang]
				}
				close DIC
			}
		}
		$self->init(language => $self->dialog(-options => \@languages, -buttons => ['okay'])) if @languages > 1
	}
	if ($self->init('language') && open(DIC, "<" . $self->init('language') . '.dic')) {
		my $line = <DIC>;
		if ($line =~ m/^\xff\xfe/) {
			close DIC;
			open DIC, "<:encoding(utf16)", $self->init('language') . '.dic';
			$line = <DIC>;
			$self->init('toolfont' => 14) unless $self->init('toolfont');
			$self->{utf16} = 1
		}
		while (<DIC>) {
			s/\n\r//g;
			if (/^\s*([^=]*[^=\s])\s*=\s*(.*\S)\s*$/) {
				my $english = _makeKey($1);
				my $foreign = $2;
				$self->{'translate'}->{$english} = $foreign;
			}
		}
		close DIC;
	}
	$self->init('toolfont' => 12) unless $self->init('toolfont');
	my $stampw = $self->init('editor') || '';
	until ((lc $stampw) =~ m/propeller.exe/ && (-e $stampw)) {
		$stampw = $self->dialog(
			-text => 'Please help me find the Propeller Editor, "Propeller.exe"',
			-explore => '/Program Files/Parallax Inc',
			-buttons => ['okay', 'cancel']
		);
		last if $stampw eq 'cancel'		
	}
	if ($stampw eq 'cancel') {
		delete $self->{init}->{editor}
	} else {
		$self->init(editor => $stampw)
	}
	$stampw = $self->init('loader');
	until ((lc $stampw) =~ m/propellent.exe/ && (-e $stampw)) {
		$stampw = $self->dialog(
			-text => 'Please help me find Propellent, "Propellent.exe"',
			-explore => '/Program Files/Parallax Inc',
			-buttons => ['okay', 'cancel']
		);
		last if $stampw eq 'cancel'		
	}
	if ($stampw eq 'cancel') {
		delete $self->{init}->{loader}
	} else {
		$self->init(loader => $stampw)
	}
	$self->saveInit;
	return $self
}

sub saveInit {
	my $self = shift;
	if (open(INI, ">$INIT_DIR/S2.ini")) {
		foreach (sort keys %{$self->{init}}) {
			print INI "$_ = ", $self->init($_), "\n"
		}
		close INI
	}	
}

sub retitle {
	my $self = shift;
	my $title = shift;
	$self->mainwindow->configure(-title => $self->translate('Scribbler Program Maker') . " (S2 v$VERSION)     $title")
}

sub enclosing {
	return undef
}

sub redraw {
}

sub clipboard {
	my $self = shift;
	if (@_) {
		my $parent = shift;
		$self->{clipboard}->children(@_);
		$self->{clipboard}->parent($parent);
		$self->{clipboard}->{counters} = $self->{clipboard}->containedCounterDepth;
		$self->{clipboard}->{depth} = $self->{clipboard}->containedLoopDepth
	}
	return $self->{clipboard}
}

sub clipboardCounterDepth {
	my $self = shift;
	return $self->{clipboard}->{counters}
}

sub clipboardLoopDepth {
	my $self = shift;
	return $self->{clipboard}->{depth}
}

sub translate {
	my ($self, $english, $capitalize) = @_;
	my $key = _makeKey($english);
	if (my $foreign = $self->{'translate'}->{$key} ) {
		if ($english eq ucfirst($english) || $capitalize) {
			if ($self->{utf16}) {
				if ($self->{init}->{language} eq 'greek') {
					my $first = ord(substr($foreign, 0, 1));
					if ($first >= 0x3b1 && $first <= 0x3c9) {
						substr($foreign, 0, 1) = chr($first - 0x20)
					}
				}
			} else {
				$foreign = ucfirst($foreign)
			}
		}
		unless ($self->{utf16}) {
			if ($foreign !~ m/[\.?!]$/) {
				$foreign .= $1 if $english =~ m/([\.?!:,;]+)$/
			}
		}
		return $foreign
	} else {
		return $english
	}
}

sub _makeKey {
	my $english = shift;
	my $key = lc $english;
	$key =~ s/^\s*(\S*)\s*$/$1/;
	$key =~ s/\s+/ /g;
	$key =~ s/[^a-z ]//g;
	return $key
}	
		
sub icon {
	my ($self, $name) = @_;
	$self->{'images'}->{'icon'}->{$name}
}

sub button {
	my ($self, $name) = @_;
	$self->{'images'}->{'button'}->{$name}
}

sub tile {
	my ($self, $name) = @_;
	$self->{'images'}->{'tile'}->{$name}
}

sub cursor {
	my ($self, $name) = @_;
	$self->{'images'}->{'cursor'}->{$name}
}

sub lcd {
	my ($self, $digit) = @_;
	$self->{'images'}->{'lcd'}->{$digit}
}

sub counter {
	my ($self, $digit) = @_;
	$self->{'images'}->{'counter'}->{$digit}
}

sub image {
	my ($self, $type, $name) = @_;
	$self->{'images'}->{$type}->{$name}
}

sub windowIcon {
	my ($self, $mw, $icon_name) = @_;
	if ($^O eq 'MSWin32' && -e "$IMG_DIR/win_$icon_name.ico") {
		$mw->setIcon(-file => "$IMG_DIR/win_$icon_name.ico")
	} else {
		$mw->Icon(-image => $self->icon($icon_name))
	}
}

sub font {
	my ($self, $fontname) = @_;
	$self->{'fonts'}->{$fontname}
}

sub scrolled {
	my $self = shift;
	@_ ? $self->{'scrolled'} = shift : $self->{'scrolled'}
}

sub canvas {
	my $self = shift;
	return $self->{'scrolled'}->Subwidget('canvas')
}

sub size {
	my $self = shift;
	if (@_) {
		my ($xslots, $yslots) = @_;
		$xslots = $XSLOTS if $xslots < $XSLOTS;
		$yslots = $YSLOTS if $yslots < $YSLOTS;
		$xslots = int(($xslots + 9) / 10) * 10;
		$yslots = int(($yslots + 9) / 10) * 10;
		if ($xslots != $self->{size}->[0] || $yslots != $self->{size}->[1]) {
			$self->{size} = [$xslots, $yslots];
			$self->{extents} = [$xslots * $MAJOR_XGRID + 2 * $MINOR_GRID, $yslots * $MAJOR_YGRID + 2 * $MINOR_GRID];
			my $canvas = $self->canvas;
			$canvas->delete('<grid>');
			foreach (0 .. $yslots * $MAJOR_YGRID / $MINOR_GRID) {
				$canvas->createLine($MINOR_GRID, ($_ + 1) * $MINOR_GRID, $xslots * $MAJOR_XGRID + $MINOR_GRID, ($_ + 1) * $MINOR_GRID,
					-width => 1,
					-tags => $_ * $MINOR_GRID % $MAJOR_YGRID ? ['<grid>', 'full_only'] : '<grid>',
					-fill => $_ * $MINOR_GRID % $MAJOR_YGRID ? '#CCCCFF' : '#9999FF'
				)
			}
			foreach (0 .. $xslots * $MAJOR_XGRID / $MINOR_GRID) {
				$canvas->createLine(($_ + 1) * $MINOR_GRID, $MINOR_GRID, ($_ + 1) * $MINOR_GRID, $yslots * $MAJOR_YGRID + $MINOR_GRID,
					-width => 1,
					-tags => $_ * $MINOR_GRID % $MAJOR_XGRID ? ['<grid>', 'full_only'] : '<grid>',
					-fill => $_ * $MINOR_GRID % $MAJOR_XGRID ? '#CCCCFF' : '#9999FF'
				)
			}
			$canvas->lower('<grid>', 'all');
			$self->scrolled->configure(-scrollregion => [0, 0, $self->extents])
		}
	}
	return @{$self->{size}}
}

sub userdir {
	my $self = shift;
	return $self->{userdir}
}

sub xExtent {
	my $self = shift;
	return $self->{extents}->[0]
}

sub yExtent {
	my $self = shift;
	return $self->{extents}->[1]
}

sub extents {
	my $self = shift;
	return @{$self->{extents}};
}

sub shade {
	my $self = shift;
	$self->{'shade'}
}

sub mainwindow {
	my $self = shift;
	@_ ? $self->{'mainwindow'} = shift : $self->{'mainwindow'}
}

sub code {
	my $self = shift;
	my $section = shift;
	return $self->{code}->{lc $section} || $self->codeHeader("EXPECTED CODE FOR SECTION $section IS MISSING.")
}

sub codeHeader {
	my $self = shift;
	my $header = shift;
	return "\n'---[$header]" . '-' x (73 - length($header)) . "\n"
}

sub required {
	my $self = shift;
	my $name = lc shift;
	return $self->{required}->{$name} ? @{$self->{required}->{$name}} : ()
}

sub editor {
	my $self = shift;
	chdir $INIT_DIR;
	my $editor = $self->init('editor') || '';
	return $editor && -e $editor ? ($^O eq 'MSWin32' ? Win32::GetShortPathName($editor) : $editor) : ''
}

sub loader {
	my $self = shift;
	chdir $INIT_DIR;
	my $loader = $self->init('loader') || '';
	return $loader && -e $loader ? ($^O eq 'MSWin32' ? Win32::GetShortPathName($loader) : $loader) : ''
}

sub help {
	my $self = shift;
	chdir $INIT_DIR;
	my $helpdir = $self->init('helpdir') || '';
	return '' unless $helpdir;
	foreach my $language (lc($self->init('language')), 'english') {
		my $help = "$helpdir/$language\_help.html";
		if ($^O eq 'MSWin32') {
			$help = Win32::GetShortPathName($help);
			$help =~ s/\//\\/g
		}
		return $help if -e $help
	}
	return ''
}

sub monitor {
	my $self = shift;
	chdir $INIT_DIR;
	my $monitor = $self->init('monitor') || '';
	return '' unless $monitor && -e $monitor;
	if ($^O eq 'MSWin32') {
		$monitor = Win32::GetShortPathName($monitor);
		$monitor =~ s/\//\\/g
	}
	return $monitor
}

sub random {
	my $self = shift;
	my $bitno = $self->{random};
	if (my $n = shift) {
		my $mask = (2 ** $n - 1) << $bitno;
		$mask = ($mask >> 16 | $mask) & 0xFFFF;
		$self->{random} = ($bitno + $n) % 16;
		return $mask
	} else {
		$self->{random} = 0
	}
}

sub worksheet {
	my $self = shift;
	if (@_) {
		my $name = shift;
		my $worksheet = $self->findChildrenWith(name => $name);
		$worksheet = $self->appendChildren(Scribbler::Worksheet->new($self, $name)) unless ref $worksheet;
		$self->{'currentworksheet'}->hide if $self->{'currentworksheet'};
		$worksheet->showFull;
		$self->{'currentworksheet'} = $worksheet
	} else {
		$self->{'currentworksheet'}
	}
}

sub worksheets {
	my $self = shift;
	return $self->children
}

sub sounds {
	my $self = shift;
	return $self->{sounds}
}

sub toolWarning {
	my $self = shift;
	my $widget = shift;
	my $text = shift;
	my $mw = $widget->toplevel;
	my $warning;
	unless ($warning = $self->{toolwarning}->{$mw}) {
		$warning = $self->{toolwarning}->{$mw} = $mw->Balloon(-font => '*-*-*-*-*-*-' . $self->init('toolfont') . '-*-*-*-*-*', -state => 'balloon', -balloonposition => 'mouse', -initwait => 100, -background => 'RED', -foreground => 'WHITE');
	}
	if (ref $text) {
		$text = {map {$_ => $self->wrap($self->translate($text->{$_}))} keys %$text};
		$warning->attach($widget, -msg => $text)
	} elsif ($text ne '') {
		$warning->attach($widget, -balloonmsg => $self->wrap($self->translate($text)))
	} else {
		$warning->detach($widget)
	}
}

sub tooltip {
	my $self = shift;
	my $widget = shift;
	my $text = shift;
	my $mw = $widget->toplevel;
	my $tip;
	unless ($tip = $self->{tooltip}->{$mw}) {
		$tip = $self->{tooltip}->{$mw} = $mw->Balloon(-font => '*-*-*-*-*-*-' . $self->init('toolfont') . '-*-*-*-*-*', -state => 'balloon', -balloonposition => 'mouse', -initwait => 600, -background => '#FFFF80');
	}
	if (ref $text) {
		$text = {map {$_ => $self->wrap($self->translate($text->{$_}))} keys %$text};
		$tip->attach($widget, -msg => $text, -postcommand => [\&tooltipEnable, $self])
	} elsif ($text ne '') {
		$tip->attach($widget, -balloonmsg => $self->wrap($self->translate($text)), -postcommand => [\&tooltipEnable, $self])
	} else {
		$tip->detach($widget)
	}
}

sub tooltipEnable {
	my $self = shift;
	shift;
	return @_ ? $self->{tooltips} = shift : $self->{tooltips}
}	

sub wrap {
	my $self = shift;
	my $text = shift;
	$text =~ s/\. /\.\n/g;
	return $text
}

sub dialog {
	my $self = shift;
	my %feature;
	while (@_) {
		my $key = shift;
		my $value = shift;
		$feature{$key} = $value
	}
	my $mw = $self->mainwindow;
	my $subwindow = $mw->state eq 'normal';
	my $dialog = $mw->Toplevel(-title => $feature{-title} || 'Scribbler');
	$self->windowIcon($dialog, 'gear_green');
	$dialog->resizable(0,0);
	$dialog->withdraw;
	my $bkgnd = '#E0E0FF';
	my $frame = $dialog->Frame->pack;
	$frame->Label(-image => $self->icon('dialog'))->pack;
	my $dframe = $frame->Frame(-background => $bkgnd)->place(-x => 186, -y => 102, -anchor => 'center');
	if (my $text = $feature{-text}) {
		my @text = ref($text) ? @$text : ($text);
		$dframe->Label(
			-background => $bkgnd,
			-text => join('', map {$self->translate($_)} @text),
			-font => $self->font('dialogfont'),
			-wraplength => 300,
			-justify => $feature{-justify} || 'center'
		)->pack(-pady => 5);
	}
	my $group = 'okay';
	if ($feature{-explore}) {
		my $name = '';
		$dframe->Label(
			-textvariable => \$name,
			-relief => 'sunken',
			-background => 'WHITE',
			-borderwidth => 2,
			-width => 54
		)->pack;
		$dframe->Button(
			-text => $self->translate('Explore'),
			-command => sub {$group = $name = $dialog->getOpenFile}
		)->pack(-pady => 5)
	}
	if (my $choices = $feature{-options}) {
		foreach (@$choices) {
			$dframe->Radiobutton(
				-background => $bkgnd,
				-activebackground => $bkgnd,
				-highlightthickness => 0,
				-text => $_->[0],
				-cursor => 'hand2',
				-value => $_->[1],
				-variable => \$group,
				-font => $self->font('dialogfont')
			)->pack(-anchor => 'w');
		}
		$group = $choices->[0]->[1];
	}
	my $done = '';
	$dframe = $frame->Frame(-background => 'BLACK')->place(-x => 352, -y => 273, -anchor => 'se');
	my @buttons = $feature{-buttons} ? @{$feature{-buttons}} : $feature{-timeout} ? () : ('okay');
	foreach (reverse @buttons) {
		$dframe->ToggleButton(
			-width => $BTN_SZ,
			-height => $BTN_SZ,
			-ontrigger => 'release',
			-offtrigger => 'release',
			-onrelief => 'flat',
			-offrelief => 'flat',
			-pressrelief => 'flat',
			-onbackground => $BG,
			-offbackground => $BG,
			-borderwidth => 0,
			-cursor => 'hand2',
			-pressimage => $self->button($_ . '_press'),
			-offimage => $self->button($_ . '_release'),
			-command => $_ eq 'okay' ? sub {$done = $group} : [sub {$done = shift}, $_]
		)->pack(-side => 'right')
	}
	$dialog->protocol('WM_DELETE_WINDOW' => sub {$done = $buttons[-1]});
	$dialog->grab;
	if ($subwindow) {
		$dialog->transient($mw);
		$dialog->Popup(-popover => $mw, -overanchor => 'c', -popanchor => 'c')
	} else {
		$dialog->deiconify;
		$dialog->raise
	}
	if (my $timeout = $feature{-timeout}) {
		$mw->after($timeout, sub {$done = 'cancel'})
	}
	$dialog->waitVariable(\$done);
	$dialog->withdraw;
	$dialog->grabRelease;
	$dialog->destroy;
	return $done
}

sub floor {
	my $x = shift;
	my $ix = int($x);
	return $x >= 0 ? $ix : $x eq $ix ? $ix : $ix - 1
}

sub quotefile {
	my $self = shift;
	my $file = $self->file(shift());
	return qq("$file")
}

sub file {
	my $self = shift;
	my $file = shift;
	$file = catfile($INIT_DIR, $file) unless file_name_is_absolute($file);
	return canonpath($file)
}

sub getrun {
	my $self = shift;
	my $command = shift;
	my $text = shift;
	my $outfile = Win32::GetShortPathName($TEMP_DIR) . '\scribbler.out';
	if ($self->run("$command > $outfile", $text)) {
		open STAT, "<$outfile" or return "ERR:000-Can't open temporary file.";
		local $/ = undef;
		my $stat = <STAT>;
		close STAT;
		unlink $outfile;
		#print $stat;
		return $stat
	} else {
		return "ERR:000-Can't create process."
	}
}

sub run {
	my $self = shift;
	my $cmd = shift;
	my $text = shift;
	$cmd = Win32::GetShortPathName($INIT_DIR) . "\\$cmd";
  my $shell = $ENV{ComSpec};
	if (Win32::Process::Create(my $process, $shell, "$shell /c $cmd", 0, NORMAL_PRIORITY_CLASS | CREATE_NO_WINDOW, '.')) {
		if ($text) {
			my $mw = $self->mainwindow;
			my $mwp = $mw->Toplevel(-background => 'BLACK');
			$mwp->withdraw;
			$self->windowIcon($mwp, 'run');
			$mwp->resizable(0,0);
			$mwp->Label(-text => $self->translate($text), -foreground => 'CYAN', -font => $self->font('tilefont'), -background => 'BLACK')->pack;
			my $labProgress = $mwp->Label(-background => 'BLACK', -image => $self->icon('progress_0'))->pack;
			my $prog = 0;
			$mwp->overrideredirect(1);
			$mwp->grab;
			$mwp->transient($mw);
			$mwp->Popup(-popover => $mw, -overanchor => 'c', -popanchor => 'c');
			$mwp->update;
			until ($process->Wait(100)) {
	    	$prog = ++$prog % 4;
	    	$labProgress->configure(-image => $self->icon("progress_$prog"));
	    	$mwp->update	    	
	    }
	    $mwp->grabRelease;
	    $mwp->withdraw;
	    $mwp->destroy;
	  } else {
	  	$process->Wait(INFINITE)
	  }
	  return 1 
  } else {
  	return 0
  }
}

sub start {
	my $self = shift;
	my $file = shift;
	$file = Win32::GetShortPathName($INIT_DIR) . "\\$file";
	my $cmd = 'start ' . $file;
  my $shell = $ENV{ComSpec};
	Win32::Process::Create(my $process, $shell, "$shell /c $cmd", 0, NORMAL_PRIORITY_CLASS | CREATE_NO_WINDOW | DETACHED_PROCESS, '.')
}

1;
