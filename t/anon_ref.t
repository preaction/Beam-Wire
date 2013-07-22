
use Test::Most;
use Test::Lib;
use Beam::Wire;

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

subtest 'anonymous reference' => sub {
    my $svc;
    lives_ok { $svc = $wire->get( 'foo' ) };
    isa_ok $svc, 'Foo';
    isa_ok $svc->foo, 'Foo';
    is $svc->foo->foo, 'Bar';
};

done_testing;
