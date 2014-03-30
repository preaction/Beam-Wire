package Greeting;
use Moo;
has hello => ( is => 'ro' );
has who => ( is => 'ro' );
has default => ( is => 'ro' );
sub greet {
    my ( $self, @who ) = @_;
    @who ||= $self->default;
    return join ". ", map { sprintf "%s, %s", $self->hello, $_ } @who;
}
1;
