package Scribbler::ConditionalArray;
use strict;
use Carp qw/cluck/;
use Scribbler;
use Scribbler::Constants;
use Scribbler::BlockArray;
use Scribbler::ConditionalBlock;
use base qw/Scribbler::BlockArray/;

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $parent = shift;
	my $self = Scribbler::BlockArray::new($class, $parent, @_);
	$self->children(
		Scribbler::ConditionalBlock->new($self, subclass => 'if'),
		Scribbler::ConditionalBlock->new($self, subclass => 'else')
	);
	return $self
}

sub emitCode {
	my $self = shift;
	my $worksheet = $self->worksheet;
	if ($worksheet->init('autoreadsensors')) {
		my @conditionals;
		my %sensors;
		foreach my $block ($self->children) {
			push @conditionals, $block->findChildrenWith(subclass => $_) foreach qw/if_begin unless_begin andif andunless/
		}
		foreach (@conditionals) {
			$_->action('icon') =~ m/([^_]+)/;
			$sensors{$1} = $_
		}
		foreach (keys %sensors) {
			Scribbler::SensorReadTile::emitCode($sensors{$_}) unless $self->subroutine->observed($_)
		}	
	}
	$self->SUPER::emitCode;
	#$worksheet->appendCode('ENDIF')
}

sub redraw {
	my $self = shift;
	return unless $self->worksheet;
	$self->SUPER::redraw;
	foreach my $block ($self->children) {
		$block->child($_)->drawVectors foreach (0, -1)
	}
	return $self->size
}

sub icon {
	return 'if_else'
}

sub priority {
	return 1
}

1;
