
use Test::More;
use Test::Exception;
use Test::Lib;
use Beam::Wire;

subtest 'method with no arguments' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'Foo',
                args  => {
                    foo => {
                        '$ref' => 'greeting',
                        '$method' => 'greet',
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
        },
    );
    my $svc;
    lives_ok { $svc = $wire->get( 'foo' ) };
    isa_ok $svc, 'Foo';
    is $svc->foo, 'Hello, World' or diag explain $svc->foo;
};

subtest 'method with one argument' => sub {
    my $wire = Beam::Wire->new(
        config => {
            bar => {
                class => 'Foo',
                args => {
                    foo => {
                        '$ref' => 'greeting',
                        '$method' => 'greet',
                        '$args' => 'Bar',
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
        },
    );
    my $svc;
    lives_ok { $svc = $wire->get( 'bar' ) };
    isa_ok $svc, 'Foo';
    is $svc->foo, 'Hello, Bar' or diag explain $svc->foo;
};

subtest 'method with arrayref of arguments' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo_and_bar => {
                class => 'Foo',
                args => {
                    foo => {
                        '$ref' => 'greeting',
                        '$method' => 'greet',
                        '$args' => [ 'Foo', 'Bar' ],
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
        },
    );
    my $svc;
    lives_ok { $svc = $wire->get( 'foo_and_bar' ) };
    isa_ok $svc, 'Foo';
    is $svc->foo, 'Hello, Foo. Hello, Bar' or diag explain $svc->foo;
};

subtest 'a different method reference' => sub {
    my $wire = Beam::Wire->new(
        config => {
            francais => {
                class => 'Foo',
                args => {
                    foo => {
                        '$ref' => 'bonjour',
                        '$method' => 'greet',
                        '$args' => 'Foo',
                    },
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
    my $svc;
    lives_ok { $svc = $wire->get( 'francais' ) };
    isa_ok $svc, 'Foo';
    is $svc->foo, 'Bonjour, Foo' or diag explain $svc->foo;
};

subtest 'path reference' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'Foo',
                args  => {
                    foo => {
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
    isa_ok $foo, 'Foo';
    is $foo->foo, 'Hello, World' or diag explain $foo->foo;
};

subtest 'anonymous reference' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'Foo',
                args  => {
                    foo => {
                        '$class' => 'Foo',
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
    isa_ok $svc, 'Foo';
    isa_ok $svc->foo, 'Foo';
    is $svc->foo->foo, 'Bar';
};

subtest 'anonymous extends' => sub {
    my $wire = Beam::Wire->new(
        config => {
            bar => {
                class => 'Foo',
                args => {
                    foo => 'HIDDEN',
                },
            },
            foo => {
                class => 'Foo',
                args  => {
                    foo => {
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
    isa_ok $svc, 'Foo';
    isa_ok $svc->foo, 'Foo';
    is $svc->foo->foo, 'Bar';
};

done_testing;
