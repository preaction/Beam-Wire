
use Test::Most;
use Test::Lib;
use Beam::Wire;

subtest 'load module from config' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'Foo',
                args  => {
                    foo => 'Hello, World',
                },
            },
        },
    );

    my $foo;
    lives_ok { $foo = $wire->get( 'foo' ) };
    isa_ok $foo, 'Foo';
    is $foo->foo, 'Hello, World';
};

done_testing;
