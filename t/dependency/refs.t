
use Test::More;
use Test::Exception;
use Test::Lib;
use Test::Deep;
use Beam::Wire;

subtest 'method with no arguments' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'My::RefTest',
                args  => {
                    got_ref => {
                        '$ref' => 'greeting',
                        '$method' => 'got_args_hash',
                    },
                },
            },
            greeting => {
                class => 'My::ArgsTest',
                args => {
                    hello => "Hello",
                    default => 'World',
                },
            },
        },
    );
    my $svc;
    lives_ok { $svc = $wire->get( 'foo' ) };
    isa_ok $svc, 'My::RefTest';
    cmp_deeply $svc->got_ref, { hello => 'Hello', default => 'World' }
        or diag explain $svc->got_ref;
};

subtest 'method with one argument' => sub {
    my $wire = Beam::Wire->new(
        config => {
            bar => {
                class => 'My::RefTest',
                args => {
                    got_ref => {
                        '$ref' => 'greeting',
                        '$method' => 'got_args_hash',
                        '$args' => 'hello',
                    },
                },
            },
            greeting => {
                class => 'My::ArgsTest',
                args => {
                    hello => "Hello",
                    default => 'World',
                },
            },
        },
    );
    my $svc;
    lives_ok { $svc = $wire->get( 'bar' ) };
    isa_ok $svc, 'My::RefTest';
    cmp_deeply $svc->got_ref, [ 'Hello' ] or diag explain $svc->got_ref;
};

subtest 'method with arrayref of arguments' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo_and_bar => {
                class => 'My::RefTest',
                args => {
                    got_ref => {
                        '$ref' => 'greeting',
                        '$method' => 'got_args_hash',
                        '$args' => [ 'default', 'hello' ],
                    },
                },
            },
            greeting => {
                class => 'My::ArgsTest',
                args => {
                    hello => "Hello",
                    default => 'World',
                },
            },
        },
    );
    my $svc;
    lives_ok { $svc = $wire->get( 'foo_and_bar' ) };
    isa_ok $svc, 'My::RefTest';
    cmp_deeply $svc->got_ref, [ 'World', 'Hello' ] or diag explain $svc->got_ref;
};

subtest 'path reference' => sub {
    # XXX: Deprecate this for $value => $path
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'My::RefTest',
                args  => {
                    got_ref => {
                        '$ref'  => 'config',
                        '$path' => '//en/greeting'
                    }
                },
            },
            config => {
                value => {
                    en => {
                        greeting => 'Hello, World'
                    }
                }
            }
        },
    );

    my $foo;
    lives_ok { $foo = $wire->get( 'foo' ) };
    isa_ok $foo, 'My::RefTest';
    is $foo->got_ref, 'Hello, World' or diag explain $foo->got_ref;
};

subtest 'anonymous reference' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'My::RefTest',
                args  => {
                    got_ref => {
                        '$class' => 'My::ArgsTest',
                        '$args' => {
                            foo => 'Bar',
                        },
                    },
                },
            },
        },
    );

    my $svc;
    lives_ok { $svc = $wire->get( 'foo' ) };
    isa_ok $svc, 'My::RefTest';
    isa_ok $svc->got_ref, 'My::ArgsTest';
    cmp_deeply $svc->got_ref->got_args_hash, { foo => 'Bar' };
};

subtest 'anonymous extends' => sub {
    my $wire = Beam::Wire->new(
        config => {
            bar => {
                class => 'My::ArgsTest',
                args => {
                    foo => 'HIDDEN',
                },
            },
            foo => {
                class => 'My::RefTest',
                args  => {
                    got_ref => {
                        '$extends' => 'bar',
                        '$args' => {
                            foo => 'Bar',
                        },
                    },
                },
            },
        },
    );

    my $svc;
    lives_ok { $svc = $wire->get( 'foo' ) };
    isa_ok $svc, 'My::RefTest';
    isa_ok $svc->got_ref, 'My::ArgsTest';
    cmp_deeply $svc->got_ref->got_args_hash, { foo => 'Bar' };
};

done_testing;
