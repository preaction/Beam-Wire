
use Test::Most;
use FindBin qw( $Bin );
use File::Spec::Functions qw( catdir );
use lib catdir( $Bin , 'lib' );
use Beam::Wire;

{ package Greeting;
    use Moo;
    has hello => ( is => 'ro' );
    has default => ( is => 'ro' );
    sub greet {
        my ( $self, @who ) = @_;
        @who = $self->default if !@who;
        return join ". ", map { sprintf "%s, %s", $self->hello, $_ } @who;
    }
}


my $wire = Beam::Wire->new(
    config => {
        foo => {
            class => 'Foo',
            args  => {
                foo => {
                    ref => 'greeting',
                    method => 'greet',
                },
            },
        },
        bar => {
            class => 'Foo',
            args => {
                foo => {
                    ref => 'greeting',
                    method => 'greet',
                    args => 'Bar',
                },
            },
        },
        foo_and_bar => {
            class => 'Foo',
            args => {
                foo => {
                    ref => 'greeting',
                    method => 'greet',
                    args => [ 'Foo', 'Bar' ],
                },
            },
        },
        francais => {
            class => 'Foo',
            args => {
                foo => {
                    ref => 'bonjour',
                    method => 'greet',
                    args => 'Foo',
                },
            },
        },

        greeting => {
            class => 'Greeting',
            args => {
                hello => "Hello",
                default => 'World',
            },
        },

        bonjour => {
            class => 'Greeting',
            args => {
                hello => 'Bonjour',
                default => 'Tout Le Monde',
            },
        },
    },
);

subtest 'method with no arguments' => sub {
    my $svc;
    lives_ok { $svc = $wire->get( 'foo' ) };
    isa_ok $svc, 'Foo';
    is $svc->foo, 'Hello, World';
};

subtest 'method with one argument' => sub {
    my $svc;
    lives_ok { $svc = $wire->get( 'bar' ) };
    isa_ok $svc, 'Foo';
    is $svc->foo, 'Hello, Bar';
};

subtest 'method with arrayref of arguments' => sub {
    my $svc;
    lives_ok { $svc = $wire->get( 'foo_and_bar' ) };
    isa_ok $svc, 'Foo';
    is $svc->foo, 'Hello, Foo. Hello, Bar';
};

subtest 'a different reference' => sub {
    my $svc;
    lives_ok { $svc = $wire->get( 'francais' ) };
    isa_ok $svc, 'Foo';
    is $svc->foo, 'Bonjour, Foo';
};

done_testing;
