
use Test::More;
use Test::Exception;
use Beam::Wire;
use Test::Lib;
use Scalar::Util qw( blessed );
use FindBin qw( $Bin );
use Path::Tiny qw( path );

subtest 'bare service with $ref' => sub {
    my %config = (
        malcolm => {
            class => 'My::Actor',
            args => {
                name => 'Nathan Fillion',
            },
        },
        foo => {
            bar => {
                '$ref' => 'malcolm',
            },
        },
    );

    my $wire = Beam::Wire->new( config => \%config );
    my $hashref;
    lives_ok { $hashref = $wire->get( 'foo' ) };
    is ref $hashref, 'HASH';
    ok !blessed $hashref, 'hashref is a plain hashref';
    is $hashref->{bar}->name, 'Nathan Fillion', 'refs are resolved';

    my $actor;
    lives_ok { $actor = $wire->get( 'foo/bar' ) };
    is $actor->name, 'Nathan Fillion', 'check name';

    lives_ok { $hashref = $wire->get( 'foo' ) };
    ok !blessed $hashref, 'hashref is still a plain hashref';
};

subtest 'bare service with $class' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                bar => {
                    '$class' => 'My::Actor',
                    name => 'Gina Torres',
                },
            },
        }
    );

    my $actor;
    lives_ok { $actor = $wire->get( 'foo/bar' ) };
    is $actor->name, 'Gina Torres', 'check name';
};

subtest 'bare service referencing explicit value service' => sub {
    my $wire = Beam::Wire->new(
        config => {
            malcolm => {
                value => 'Nathan Fillion',
            },
            foo => {
                bar => {
                    '$ref' => 'malcolm',
                },
            },
        }
    );

    my $actor;
    lives_ok { $actor = $wire->get( 'foo/bar' ) };
    is $actor, 'Nathan Fillion', 'got the value service';
};

subtest 'bare service referencing external container file' => sub {
    my $dir   = path( $Bin, '..', 'share', 'beam_path' );
    my $wire = Beam::Wire->new(
        dir => [$dir],
        config => {
            foo => {
                bar => {
                    '$class' => 'Beam::Wire',
                    file => 'file.yml',
                },
            },
        }
    );

    my $svc;
    lives_ok { $svc = $wire->get( 'foo/bar/foo' ) };
    isa_ok $svc, 'My::Service';
};

done_testing;
