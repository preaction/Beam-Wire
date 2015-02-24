package
    My::Listener;

use Moo;

has events_seen => (
    is => 'rw',
    default => sub { 0 },
);

sub on_greet {
    my ( $self ) = @_;
    $self->events_seen( $self->events_seen + 1 );
    return;
}

1;
