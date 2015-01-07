package Scribbler::ConditionalBlock;
use strict;
use Carp qw/cluck/;
use Scribbler;
use Scribbler::Constants;
use Scribbler::AtomBlock;
use Scribbler::ConditionalTile;
use base qw/Scribbler::AtomBlock/;

sub new {
	my $invocant = shift;
	my $parent = shift;
	my $class = ref($invocant) || $invocant;
	my $self = Scribbler::AtomBlock::new($class, $parent, @_);
	$self->subclass('if') unless $self->subclass;
	my %tile;
	foreach (qw/begin end/) {
		$tile{$_} = Scribbler::ConditionalTile->new($self, subclass => $self->subclass . "_$_");
		$tile{$_}->action(type => $self->subclass, icon => 'flag_green')
	}
	$self->children($tile{begin}, $tile{end});		
	return $self
}

sub emitCode {
	my $self = shift;
	my $worksheet = $self->worksheet;
	my $incondition = 1;
	my $index = $self->findMe;
	return if $index eq $self->parent->children - 1 && $self->children < 3;
	my $condition = $index ? 'else' : '';
	foreach my $tile ($self->children) {
		if ($incondition && $tile->isa('Scribbler::ConditionalTile') && $tile->subclass !~ /end/) {
			$condition .= $tile->code
		} else {
			if ($incondition) {
				$condition .= ')' if $condition =~ m/^(ELSE)?IF/i;
				$worksheet->appendCode($condition);
				$worksheet->indentCode;
				$incondition = 0
			}
			$tile->emitCode if $tile->can('emitCode');
			$tile->emitCall
		}
	}
	$worksheet->unindentCode
}

sub icon {
	return 'if_else'
}

sub priority {
	return 1
}

1;