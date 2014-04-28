package Greeting;
use Moo;
has hello => ( is => 'ro' );
has who => ( is => 'ro' );
has default => ( is => 'ro' );
use diagnostics;
sub greet {
    my ( $self, @who ) = @_;
    if ( !@who ) {
        @who = ( $self->default );
    }
    return join ". ", map { sprintf "%s, %s", $self->hello, $_ } @who;
}
1;
