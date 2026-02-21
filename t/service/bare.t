
use Test::More;
use Test::Exception;
use Beam::Wire;
use Test::Lib;

subtest 'bare service with $ref' => sub {
    my $wire = Beam::Wire->new(
        config => {
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
        }
    );

    my $actor;
    lives_ok { $actor = $wire->get( 'foo/bar' ) };
    is $actor->name, 'Nathan Fillion', 'check name';
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

done_testing;
