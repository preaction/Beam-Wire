package
    My::ArgsTest;

use Moo;

has got_args => ( is => 'ro' );
sub BUILDARGS {
    my ( $class, @args ) = @_;
    return { got_args => \@args };
}

sub got_args_hash { return { @{ $_[0]->got_args } } }

1;
