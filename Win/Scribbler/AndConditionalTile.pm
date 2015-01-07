package Scribbler::AndConditionalTile;
use strict;
use Carp qw/cluck/;
use Scribbler;
use Scribbler::Constants;
use Scribbler::AtomBlock;
use base qw/Scribbler::ConditionalTile/;

sub new {
 	my $invocant = shift;
 	my $class = ref($invocant) || $invocant;
 	my $parent = shift;
 	my $self = Scribbler::ConditionalTile::new($class, $parent, subclass => 'andif', @_)
}

sub icon {
	return 'and_if'
}

1;


