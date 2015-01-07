package Scribbler::SequencerTile;
use strict;
use Carp qw/cluck confess/;
use Tk;
require Tk::Pane;

use Scribbler;
use Scribbler::Constants;
use Scribbler::AtomBlock;
use Scribbler::SoundPlayer;
use Scribbler::SoundBite;
use base qw/Scribbler::ActionTile/;

my $AbbrColor = '#0475B5';
my @FreqBuf = ();
my @DurBuf = ();

sub new {
 	my $invocant = shift;
 	my $class = ref($invocant) || $invocant;
 	my $parent = shift;
 	my $self = Scribbler::ActionTile::new($class, $parent, @_);
 	$self->action(icon => 'tune', text => '', call => '', sequence => []);
 	return $self
}

sub emitCode {
	my $self = shift;
	my $worksheet = $self->worksheet;
	my @sequence = @{$self->action('sequence')};
	my $tempo = 1.25 ** ($self->action('tempo') - 5);
	my $loopindex;

	foreach my $bite (@sequence) {
		my $notelength = eval($bite->noteLength) * 4;
		my $notetranspose = 1.059463094 ** ($bite->noteTranspose);
		foreach my $note ($bite->notes) {
			my $type = $note->{type};
			
			if ($type eq 'loopbegin') {
				
				my ($from, $to, $step) = @{$note->{reps}};
				
				if ($to < $from) {
					$worksheet->appendCode("repeat SeqCounter from $to to $from" . ($step > 1 ? " step $step" : ''));
					$worksheet->indentCode;
					$loopindex = '(' . ($from + $to) . " - SeqCounter)";
				} else {
					$worksheet->appendCode("repeat SeqCounter from $from to $to" . ($step > 1 ? " step $step" : ''));
					$worksheet->indentCode;
					$loopindex = "SeqCounter"
				}
				
			} elsif ($type =~ m/^(if|elseif)$/) {
				
				my $condition = $note->{condition};
				$worksheet->unindentCode if $type eq 'elseif';
				$worksheet->appendCode($type . " ($loopindex == $condition)");
				$worksheet->indentCode
				
			} elsif ($type eq 'endif') {
				
				$worksheet->unindentCode;
				#$worksheet->appendCode('ENDIF')
				
			} elsif ($type eq 'loopend') {
				
				$worksheet->unindentCode;
				#$worksheet->appendCode('NEXT');

			} else {
				
				my ($freq, $fmult, $duration, $dmult) = map {$note->{$_}} qw/frequency fmult duration dmult/;
				$fmult *= $notetranspose;
				$dmult *= $notelength;
				my $ffact = $fmult < 1 ? ' / ' . int(1 / $fmult) : $fmult > 1 ? ' * ' . int($fmult) : '';
				my $dfact = $dmult < 1 ? ' / ' . int(1 / $dmult) : $dmult > 1 ? ' * ' . int($dmult) : '';
				
				if ($freq eq '$') {
					$freq = "$loopindex$ffact, 0"
				} elsif (ref $freq) {
					$freq = int($freq->[0] * $notetranspose) . ', ' . int($freq->[1] * $notetranspose)
				} else {
					$freq = int($freq * $fmult) . ', 0'
				}
				
				if ($duration eq '$') {
					$duration = "$loopindex$dfact"
				} else {
					$duration = int($duration * $dmult / $tempo)
				}
								
				if ($type eq 'pulse') {
					
						$worksheet->emitCall("PlayPulse($freq, $duration)")
					
						#$worksheet->appendCode("PULSOUT Speaker, $freq");
						#$worksheet->appendCode("PAUSE $duration") if $duration
						
				} elsif ($freq) {
				
					$worksheet->emitCall("PlayNote($duration, $freq)") if $duration
					
				} else {
					
					$worksheet->emitCall("PlayNote($duration, 0, 0)") if $duration
					
				}
				
			}
		}
	}
	$worksheet->appendCode("s2.wait_sync(0)")
}

sub decode {
	my $self = shift;
	my $code = shift;
	my $action = $code->{action};
	$self->configure(map {($_ => $code->{$_})} grep {$_ ne 'action'} keys %$code);
	$self->action(map {($_ => $action->{$_})} grep {$_ ne 'sequence'} keys %{$action});
	foreach my $bite (@{$action->{sequence}}) {
		my $biteobj = Scribbler::SoundBite->new(map {($_ => $bite->{$_})} grep {$_ ne 'class'} keys %{$bite});
		push @{$self->{action}->{sequence}}, $biteobj;
		$self->_createImage($biteobj)
	}
}

my ($Self, $EditWindow, $CanSeq, $Selection, $BtnPlay, %BtnSeq, @Sequence, $Freq, $NoteLength, $NoteTranspose, $Duration, $ScaTempo);
my (@Slots, $Tempo, $Descr, $PrvDescr, $PlayMonitor, @CanCall, $CallIndex);
my $Playing = 0;
my $Volume = 50;
my $Player = Scribbler::SoundPlayer->new;

sub editor {
	$Self = shift;
	@Sequence = @{$Self->action('sequence') || []};
	$Tempo = $Self->action('tempo') || 5;
	@CanCall = ('', $Self->subroutine->canCall);
	$CallIndex = (grep $CanCall[$_] eq $Self->action('call'), (0 .. @CanCall - 1))[0] || 0;
	undef @Slots;
	$EditWindow = $Self->_createEditWindow() unless $EditWindow;
	undef $Selection;
	_redraw(@Sequence ? @Sequence - 1 : undef);
	_updateCall();
	return $EditWindow
}

sub _createEditWindow {
	my $self = shift;
	my $scribbler = $self->scribbler;
	my $bodycolor = '#5A7787';
	my $tilecolor = '#00E700';
	my $selectcolor = 'CYAN';
	my $mw = $scribbler->mainwindow->Toplevel(-background => $BG, -title => $scribbler->translate('create sounds', 1));
	$mw->withdraw;
	$scribbler->windowIcon($mw, 'tune');
	my $frame2 = $mw->Frame(
		-background => $bodycolor, 
		-relief => 'raised', 
		-borderwidth => 2
	)->pack(-side => 'left', -expand => 1, -fill => 'y');
	my $frame1 = $mw->Frame(-background => $BG)->pack(-side => 'right');
	my $frame3 = $frame1->Frame(-background => $BG)->pack(-side => 'right');
	my $frame4 = $frame3->Frame(-background => $BG)->pack(-side => 'top');
	my $frame5 = $frame3->Frame(
		-background => $bodycolor,
		-relief => 'raised', -borderwidth => 2
	)->pack(-side => 'top', -expand => 1, -fill => 'x');
	my $frame6 = $frame3->Frame(-background => $BG)->pack(-side => 'bottom', -expand => 1, -fill => 'x');
	
	$frame2->Label(
		-background => $bodycolor,
		-foreground => 'LIGHTBLUE',
		-font => $scribbler->font('tilefont'),
		-text => $scribbler->translate('Sound Library'),
	)->pack;
	
	my $frame2a = $frame2->Frame(
		-background => $bodycolor
	)->pack(-expand => 1, -fill => 'both', -padx => 7, -pady => 7);
	
	my $fralib = $frame2a->Scrolled('Pane', 
		-background => 'BLACK',
		-width => 240,
		-height => 100,
		-borderwidth => 0,
		-scrollbars => 'e',
	)->pack(-expand => 1, -fill => 'both');
		
	$fralib->Subwidget('yscrollbar')->configure(
		-background => $bodycolor,
		-highlightbackground => $bodycolor,
		-activebackground => 'CYAN',
		-cursor => 'hand2',
		-troughcolor => $bodycolor
	);
	
	my $lib = $scribbler->sounds;
	my @groups = $lib->groups;
	my $firstbar = 0;
	foreach my $group (@groups) {
		next unless $lib->soundbites($group);
		
		if ($firstbar) {
			$fralib->Frame(
				-background => $AbbrColor,
				-relief => 'raised',
				-borderwidth => 2,
				-height => 4
			)->pack(-expand => 1, -fill => 'x');
		} else {
			$firstbar = 1
		}		
				
		$fralib->Label(
			-background => 'BLACK',
			-image => $scribbler->icon(lc $group)
		)->pack(-anchor => 'nw');
			
		my $x = 8; my $y = 0; my $fra;
		foreach my $bite ($lib->soundbites($group))	{
			my $abbr = $bite->abbr;
			my $bars = $bite->bars;
			my $size = $bars || 1;
			my $color = $bite->color;
			if ($x + $size > 8) {
				$fra = $fralib->Frame(-background => 'BLACK')->pack(-expand => 1, -fill => 'x');
				$x = 0;
			}
			my $comp = $self->_createImage($bite);
			my $lab = $fra->Label(
				-background => 'BLACK',
				-borderwidth => 0,
				-image => $comp,
				-state => 'normal'
			)->pack(-side => 'left', -padx => 2, -pady => 2);
			$lab->bind('<Button-1>' => [\&_evtInsert, $bite]);
			$lab->bind('<Button-3>' => [\&_evtPlayBite, 5, $bite]);
			$lab->bind('<ButtonRelease-3>' => [\&_evtStopBite, $bite]);
			$scribbler->tooltip($lab, 'Click to insert this sound. Right-click to hear it.');
			$x += $size
		}
	}			

	$CanSeq = $frame4->Canvas(
		-width => 260,
		-height => 220,
		-highlightthickness => 0,
		-takefocus => 0,
		-background => 'BLACK'
	)->pack(-side => 'left');
	
	$CanSeq->createImage(130, 10, -image => $scribbler->icon('sequencetile'), -anchor => 'n', -tags => 'seqtile');
	$scribbler->tooltip($CanSeq, {seqtile => 'Click on a sound to select it. Right-click to hear it.'});
	
	$CanSeq->createWindow(
		155, 46, -anchor => 'nw',
		-window => $ScaTempo = $mw->Scale(
			-background => $tilecolor,
			-foreground => $tilecolor,
			-highlightbackground => $tilecolor,
			-highlightthickness => 0,
			-activebackground => 'CYAN',
			-cursor => 'hand2',
			-showvalue => 0,
			-troughcolor => $tilecolor,
			-length => 70,
			-sliderlength => 10,
			-orient => 'horizontal',
			-from => 1,
			-to => 9,
			-width => 16,
			-borderwidth => 0,
			-variable => \$Tempo
		)
	);			
	$scribbler->tooltip($ScaTempo, 'Adjust overall tempo.');
	
	foreach my $size (1, 2, 4) {
		foreach my $col (0 .. 16 / $size - 1) {
			my $loc = $col * $size;
			my $x = int(36 + ($loc % 8) * 24);
			my $y = 76 + 38 * int($loc / 8);
			my $img = $CanSeq->createImage($x, $y, -image => undef, -anchor => 'nw', -state => 'hidden', -tags => ["I:$loc:$size", 'seq', 'image']);
			$CanSeq->bind($img, '<Button-1>', [\&_evtSelect, "$loc:$size"]);
			$CanSeq->bind($img, '<Button-3>' => [\&_evtSelectPlayBite, "$loc:$size"]);
			$CanSeq->bind($img, '<ButtonRelease-3>' => \&_evtStopBite);
			$CanSeq->createLine(
				$x - 3, $y - 3,
				$x + 23 * $size - 4, $y - 3,
				$x + 23 * $size + 9, $y + 10,
				$x + 23 * $size - 4, $y + 23,
				$x - 3, $y + 23,
				$x - 3, $y - 3,
				-width => 3,
				-fill => $selectcolor,
				-state => 'hidden',
				-joinstyle => 'round',
				-tags => ["R:$loc:$size", 'seq', 'select']
			)
		}
	}
	
	$CanSeq->bind(
		$CanSeq->createRectangle(
			0, 69, 37, 106,
			-stipple => 'transparent',
			-width => 0
		),
		'<Button-1>' => sub {_select(undef)}
	);
	
	$CanSeq->createLine(33, 73, 46, 86, 33, 99,
		-width => 3,
		-fill => $selectcolor,
		-state => 'hidden',
		-joinstyle => 'round',
		-tags => ["R:undef", 'seq', 'select']
	);
		
	$CanSeq->raise('select', 'image');
	
	$CanSeq->createWindow(
		260, 220, -anchor => 'se',
		-window => my $btnTrash = $mw->ToggleButton(
			-width => $BTN_SZ,
			-height => $BTN_SZ,
			-ontrigger => 'release',
			-offtrigger => 'release',
			-onrelief => 'flat',
			-offrelief => 'flat',
			-pressrelief => 'flat',
			-cursor => 'hand2',
			-onbackground => $BG,
			-offbackground => $BG,
			-borderwidth => 0,
			-command => \&_evtDelete,
			-pressimage => $scribbler->button('trash_press'),
			-offimage => $scribbler->button('trash_release')
		)
	);
	$scribbler->tooltip($btnTrash, 'Delete the selected sound.');
					
	#$CanSeq->CanvasBind('<Motion>' => [\&_showCoords, Ev('x'), Ev('y')]);
	
	$frame5->Label(
		-background => $bodycolor,
		-image => $scribbler->icon('note_tempo'),
		-highlightthickness => 0
	)->pack(-side => 'left');

	$frame5->Spinbox(
		-readonlybackground => 'BLACK', -foreground => 'CYAN',
		-selectbackground => 'BLACK', -selectforeground => 'CYAN',
		-takefocus => 0, -state => 'readonly', -buttonbackground => '#404040',
		-width => 4, -values => [qw(1/16 1/8 3/16 1/4 3/8 1/2 3/4 1)],
		-textvariable => \$NoteLength, -justify => 'left',
		-command => [\&_evtSpinLength, $_],
		-font => $scribbler->font('tilefont'), -repeatinterval => 25
	)->pack(-side => 'left', -padx => 5);
			
	$frame5->Label(
		-background => $bodycolor,
		-image => $scribbler->icon('note_transpose'),
		-highlightthickness => 0
	)->pack(-side => 'left');

	$frame5->Spinbox(
		-readonlybackground => 'BLACK', -foreground => 'CYAN',
		-selectbackground => 'BLACK', -selectforeground => 'CYAN',
		-takefocus => 0, -state => 'readonly', -buttonbackground => '#404040',
		-width => 4, -values => [qw(-12 0 +12 +24)],
		-textvariable => \$NoteTranspose, -justify => 'left',
		-command => [\&_evtSpinTranspose, $_],
		-font => $scribbler->font('tilefont'), -repeatinterval => 25
	)->pack(-side => 'left', -padx => 5);
			
	$frame5->Label(
		-background => $bodycolor,
		-highlightthickness => 0
	)->pack(-side => 'left', -expand => 1, -fill => 'x');

	$BtnPlay = $frame5->Button(
		-background => $bodycolor,
		-activebackground => $bodycolor,
		-borderwidth => 2,
		-command => [\&_evtPressPlay],
		-cursor => 'hand2',
		-foreground => $bodycolor,
		-highlightcolor => 'BLACK',
		-highlightbackground => 'BLACK',
		-highlightthickness => 1,
		-takefocus => 0,
		-image => $scribbler->icon("play_off"),
		-relief => 'raised'
	)->pack(-side => 'left', -padx => 2, -pady => 2);
	$scribbler->tooltip($BtnPlay, 'Start or stop testing a sound.');
	
	$frame5->Label(
		-image => $scribbler->icon('ear'),
		-background => $bodycolor
	)->pack(-side => 'left', -padx => 2, -pady => 2);
	
	my $scaVol = $frame5->Scale(
		-background => $bodycolor,
		-foreground => $bodycolor,
		-highlightbackground => $bodycolor,
		-activebackground => 'CYAN',
		-takefocus => 0,
		-cursor => 'hand2',
		-showvalue => 0,
		-troughcolor => $bodycolor,
		-length => 32,
		-sliderlength => $SLIDER_LENGTH,
		-from => 100,
		-to => 0,
		-width => $SLIDER_WIDTH,
		-borderwidth => 1,
		-variable => \$Volume,
		-command => \&_evtChangeVolume		
	)->pack(-side => 'left', -padx => 2, -pady => 2);
	$scribbler->tooltip($scaVol, 'Adjust volume.');
	
	foreach (qw/call_ no okay/) {
		$BtnSeq{$_} = $frame6->ToggleButton(
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
			) : (
				-pressimage => $scribbler->button($_ . '_press'),
				-offimage => $scribbler->button($_ . '_release'),
			),
			-command => [\&_evtClickButton, $_]
		)->pack($_ eq 'call_' ? (-side => 'left', -anchor => 'w') : (-side => 'right', -anchor => 'e'))
	}
	$scribbler->tooltip($BtnSeq{call_}, 'Select subroutine to call.');
	
	$frame6->Label(
		-background => $BG,
		-highlightthickness => 0,
		-foreground => 'CYAN',
		-font => $scribbler->font('tilefont'),
		-textvariable => \$Descr,
		-wraplength => 100
	)->pack(-side => 'left', -expand => 1, -fill => 'x');
	
	return $mw
}

sub _evtClickButton {
	my $btn = shift;
	if ($btn =~ m/okay|no/) {
		if ($btn eq 'okay') {
			my $n = @Sequence;
			my $ellipsis = '';
			if ($n > 4) {$n = 3; $ellipsis = ' ...'}
			my $text = join(' ', map {$Sequence[$_]->abbr} (0 .. $n - 1)) . $ellipsis;
			$Self->action(sequence => [@Sequence], tempo => $Tempo, call => $CanCall[$CallIndex], text => $text)
		}
		_select(undef);
		_stopBites();
		$Self->{'done'} = $btn
	} elsif ($btn eq 'call_') {
		$CallIndex = ($CallIndex + 1) % scalar(@CanCall);
		_updateCall()
	}		
}

sub _updateCall {
	my $scribbler = $Self->scribbler;
	$BtnSeq{'call_'}->pressimage($scribbler->button("multi_call_$CanCall[$CallIndex]" . ($CallIndex ? '_pushon' : '_push')));
	$BtnSeq{'call_'}->offimage($scribbler->button("multi_call_$CanCall[$CallIndex]" . ($CallIndex ? '_on' : '_off')));
}

sub _evtInsert {
	my $bite = $_[1]->clone;
	my $index = defined $Selection ? $Selection + 1 : 0;
	splice @Sequence, $index, 0, $bite;
	splice @Sequence, 32 if @Sequence > 32;
	_redraw($index);
}

sub _evtDelete {
	if (shift) {
		if (defined $Selection) {
			splice @Sequence, $Selection, 1;
			my $index =  $Selection ? $Selection - 1 : undef;
			undef $Selection;
			_redraw($index);
		}
	}
}

sub _redraw {
	my $selindex = shift;
	my $selloc;
	$CanSeq->itemconfigure('seq', -state => 'hidden');
	my $loc = 0;
	foreach (0 .. @Sequence - 1) {
		my $bite = $Sequence[$_];
		my $size = $bite->size;
		$loc = int($loc / $size + 1) * $size if $loc % $size;
		if ($loc + $size > 16) {
			splice @Sequence, $_;
			$selindex = $_ - 1 if defined $selindex;
			last
		}
		$bite->location($loc);
		my $image = $bite->image;
		$CanSeq->itemconfigure("I:$loc:$size", -image => $image, -state => 'normal');
		$selloc = $loc if defined $selindex && $_ <= $selindex && $loc + $size < 16;
		$loc += $size
	}
	_select($selindex)
}

sub _evtSelectPlayBite {
	_evtSelect(@_);
	_evtPlayBite(undef, $Tempo, $Sequence[$Selection]) if defined $Selection
}	

sub _evtSelect {
	my ($canvas, $locsize) = @_;
	my $sel = (grep {$Sequence[$_]->locsize eq $locsize} (0 .. @Sequence - 1))[0];
	_select($sel)
}

sub _select {
	my $loc = shift;
	$CanSeq->itemconfigure('R:' . (defined $Selection ? $Sequence[$Selection]->locsize : 'undef'), -state => 'hidden');
	$CanSeq->itemconfigure('R:' . (defined $loc ? $Sequence[$loc]->locsize : 'undef'), -state => 'normal');
	$Selection = $loc;
	if (defined $Selection) {
		$NoteLength = $Sequence[$Selection]->noteLength;
		$NoteTranspose = $Sequence[$Selection]->noteTranspose;
	} else {
		$NoteLength = '1/4';
		$NoteTranspose = '0'
	}
}

sub _evtSpinLength {
	if (defined $Selection) {
		$Sequence[$Selection]->noteLength($NoteLength);
	}
}	

sub _evtSpinTranspose {
	if (defined $Selection) {
		$Sequence[$Selection]->noteTranspose($NoteTranspose);
	}
}	

sub _evtPlayBite {
	my (undef, $tempo, $bite) = @_;
	$PrvDescr = $Descr || '';
	$Descr = $bite->comment;
	_playBites($tempo, $bite)
}

sub _evtStopBite {
	$Descr = $PrvDescr;
	_stopBites()
}

sub _evtPressPlay {
	$Playing ? _stopBites() : _playBites($Tempo, @Sequence);
}

sub _evtChangeVolume {
	$Player->volume($Volume)
}

sub _playBites {
	$ScaTempo->configure(-state => 'disabled');
	my $tempo = shift;
	$Player->volume($Volume);
	$Player->playBites(1.25 ** ($tempo - 5), @_);
	$BtnPlay->configure(-image => $Self->scribbler->icon('play_on'));
	$Playing = 1;
	$PlayMonitor = $CanSeq->repeat(100, sub{$Player->done && _stopBites()});
}

sub _stopBites {
	$Player->stop;
	$BtnPlay->configure(-image => $Self->scribbler->icon('play_off'));
	$Playing = 0;
	if ($PlayMonitor) {
		$CanSeq->afterCancel($PlayMonitor);
		undef $PlayMonitor
	}
	$ScaTempo->configure(-state => 'normal');
}

sub _showCoords {
	my (undef, $x, $y) = @_;
	$Descr = "$x, $y"
}

sub _createImage {
	my $self = shift;
	my $bite = shift;
	my $scribbler = $self->scribbler;
	my $bars = $bite->bars;
	my $abbr = $bite->abbr;
	my $color = $bite->color;
	my $comp = $scribbler->mainwindow->Compound;
	$comp->Image(-image => $scribbler->icon("seq_$bars\_$color"));
	$comp->Line;
	$comp->Text(-text => $abbr, -foreground => $AbbrColor, -font => $scribbler->font('smallfont'));
	$bite->configure(image => $comp);
	return $comp
}

1;
