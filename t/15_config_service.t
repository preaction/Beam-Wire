
use Test::More;
use Test::Deep;
use Test::Exception;
use Test::Lib;
use Beam::Wire;
use Path::Tiny qw( path tempdir cwd );
use FindBin qw( $Bin );
my $SHARE_DIR = path( $Bin, 'share' );

my $EXPECT = {
    foo => 'bar',
    baz => [qw( 1 2 3 )],
    obj => {
        # References do not get resolved by $config
        '$class' => 'Beam::Wire',
        '$args' => {
            services => {
                foo => 'bar',
            },
        },
    },
};

subtest 'yaml config file' => sub {
    my $wire = Beam::Wire->new(
        config => {
            yaml => {
                config => $SHARE_DIR->child( 'config', 'config.yml' )->stringify,
            },
        },
    );

    my $svc;
    lives_ok { $svc = $wire->get( 'yaml' ) };
    cmp_deeply $svc, $EXPECT;

    subtest 'config is relative to container file location' => sub {
        my $wire = Beam::Wire->new(
            file => $SHARE_DIR->child( 'with_config.yml' )->relative( cwd )->stringify,
        );

        my $svc;
        lives_ok { $svc = $wire->get( 'yaml' ) };
        cmp_deeply $svc, $EXPECT;
    };

    subtest 'absolute path works' => sub {
        my $wire = Beam::Wire->new(
            file => $SHARE_DIR->child( 'with_config.yml' )->stringify,
        );

        my $svc;
        lives_ok { $svc = $wire->get( 'yaml' ) };
        cmp_deeply $svc, $EXPECT;
    };
};

subtest 'anonymous configs' => sub {

    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'Foo',
                args  => {
                    foo => {
                        '$config' => $SHARE_DIR->child( config => 'config.yml' )->stringify,
                    },
                },
            },
        },
    );

    my $svc;
    lives_ok { $svc = $wire->get( 'foo' ) };
    isa_ok $svc, 'Foo';
    cmp_deeply $svc->foo, $EXPECT;
};

subtest 'config references' => sub {

    subtest 'ref a config' => sub {
        my $wire = Beam::Wire->new(
            config => {
                yaml => {
                    config => $SHARE_DIR->child( config => 'config.yml' )->stringify,
                },
                foo => {
                    class => 'Foo',
                    args  => {
                        foo => {
                            '$ref' => 'yaml',
                        },
                    },
                },
            },
        );

        my $svc;
        lives_ok { $svc = $wire->get( 'foo' ) };
        isa_ok $svc, 'Foo';
        cmp_deeply $svc->foo, $EXPECT;
    };

    subtest 'ref a path in a config' => sub {
        my $wire = Beam::Wire->new(
            config => {
                yaml => {
                    config => $SHARE_DIR->child( config => 'config.yml' )->stringify,
                },
                foo => {
                    class => 'Foo',
                    args  => {
                        foo => {
                            '$ref' => 'yaml',
                            '$path' => '/foo',
                        },
                    },
                },
            },
        );

        my $svc;
        lives_ok { $svc = $wire->get( 'foo' ) };
        isa_ok $svc, 'Foo';
        cmp_deeply $svc->foo, $EXPECT->{foo} or diag explain $svc->foo;
    };
};

done_testing;
