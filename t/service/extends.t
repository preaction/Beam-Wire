
use Test::More;
use Test::Exception;
use Test::Deep;
use Test::Lib;
use Beam::Wire;

{   package Foo;
    use Moo;
    has foo => is => 'ro';
    my $singleton;
    sub BUILDARGS {
        my ( $class, @args ) = @_;
        # Support scalar and array constructor args
        if ( @args == 1 && ref $args[0] ne 'HASH' ) {
            @args = ( foo => $args[0] );
        }
        return ref $args[0] ? $args[0] : {@args};
    }
    sub instance {
        my ( $class, @args ) = @_;
        if ( $singleton && @args ) {
            die "Singleton is already made!\n";
        }
        # No, I do not know why you'd ever do this
        return $singleton ||= $class->new( @args );
    }
    sub dies { die; } # Exactly as advertised
}
local $INC{"Foo.pm"} = __FILE__;

subtest 'scalar args' => sub {
    my $wire = Beam::Wire->new(
        config => {
            base_scalar => {
                class => 'Foo',
                args  => 'Hello, World',
            },
            scalar_no_change => {
                extends => 'base_scalar',
            },
            scalar => {
                extends => 'base_scalar',
                args => 'Goodbye, World',
            },

            base_method => {
                extends => 'base_scalar',
                method => 'dies',
            },

            scalar_nested_extends => {
                extends => 'base_method',
                method => 'new',
            },
        },
    );

    subtest 'extends scalar args, new args' => sub {
        my $svc;
        lives_ok { $svc = $wire->get( 'scalar' ) };
        isa_ok $svc, 'Foo';
        is $svc->foo, 'Goodbye, World';
    };

    subtest 'extends scalar args, no changes' => sub {
        my $svc;
        lives_ok { $svc = $wire->get( 'scalar_no_change' ) };
        isa_ok $svc, 'Foo';
        is $svc->foo, 'Hello, World';
    };

    subtest 'extends scalar args, new method, extends another extends' => sub {
        my $svc;
        dies_ok { $svc = $wire->get( 'base_method' ) };
        lives_ok { $svc = $wire->get( 'scalar_nested_extends' ) };
        isa_ok $svc, 'Foo';
        is $svc->foo, 'Hello, World';
    };
};

subtest 'array args' => sub {
    my $wire = Beam::Wire->new(
        config => {
            base_array => {
                class => 'Foo',
                args => [ [ 'Hello', 'World' ] ],
            },
            array => {
                extends => 'base_array',
                args => [ [ 'Goodbye', 'World' ] ],
            },
            replace_with_hash => {
                extends => 'base_array',
                args => {
                    foo => 'Hello',
                },
            },
        },
    );

    subtest 'extends array args, new args' => sub {
        my $svc;
        lives_ok { $svc = $wire->get( 'array' ) };
        isa_ok $svc, 'Foo';
        cmp_deeply $svc->foo, [ 'Goodbye', 'World' ];
    };

    subtest 'extends array args, change to hash args' => sub {
        my $svc;
        lives_ok { $svc = $wire->get( 'replace_with_hash' ) };
        isa_ok $svc, 'Foo';
        is $svc->foo, 'Hello';
    };
};

subtest 'hash args' => sub {
    my $wire = Beam::Wire->new(
        config => {
            base_hash => {
                class => 'Greeting',
                args => {
                    hello => 'Hello',
                    who => 'World',
                },
            },
            hash => {
                extends => 'base_hash',
                args => {
                    who => 'Everyone',
                },
            },
        },
    );

    subtest 'extends hash args, new args' => sub {
        my $svc;
        lives_ok { $svc = $wire->get( 'hash' ) };
        isa_ok $svc, 'Greeting';
        is $svc->hello, 'Hello';
        is $svc->who, 'Everyone';
    };
};

subtest 'nested data structures' => sub {
    my $wire = Beam::Wire->new(
        config => {
            base_arraynest => {
                class => 'Foo',
                args => [ [
                    'Hello', 
                    [
                        { English => 'World' },
                        { French => 'Tout Le Monde' },
                    ],
                ] ],
            },
            base_hashnest => {
                class => 'Greeting',
                args => {
                    hello => {
                        English => 'Hello',
                        French => 'Bonjour',
                    },
                    who => [
                        { English => 'World' },
                        { French => 'Tout Le Monde' },
                    ],
                },
            },
            arraynest => {
                extends => 'base_arraynest',
                args => [ [
                    'Goodbye',
                    [
                        { Spanish => 'Mundo' },
                    ],
                ] ],
            },
            hashnest => {
                extends => 'base_hashnest',
                args => {
                    who => [
                        { Spanish => 'Mundo' },
                    ],
                },
            },
        },
    );

    subtest 'extends arraynest, new args' => sub {
        # These pathological cases are for later if we decide to
        # do this kind of merging differently
        my $svc;
        lives_ok { $svc = $wire->get( 'arraynest' ) };
        isa_ok $svc, 'Foo';
        cmp_deeply $svc->foo, [ 'Goodbye', [ { Spanish => 'Mundo' } ] ];
    };
    subtest 'extends hashnest, new args' => sub {
        my $svc;
        lives_ok { $svc = $wire->get( 'hashnest' ) };
        isa_ok $svc, 'Greeting';
        cmp_deeply $svc->hello, { English => 'Hello', French => 'Bonjour' };
        cmp_deeply $svc->who, [ { Spanish => 'Mundo' } ];
    };
};

subtest 'extended service does not exist' => sub {
    my $wire;
    lives_ok {
        $wire = Beam::Wire->new(
            config => {
                hash => {
                    extends => 'base_hash',
                    args => {
                        who => 'Everyone',
                    },
                },
            },
        );
    } 'creating a bad wire is fine';
    dies_ok { $wire->get( 'hash' ) } 'getting a bad service is not';
};

done_testing;
