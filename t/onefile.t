
use Test::Most;
use Beam::Wire;

{

    package Foo;

    use Moo;

    has 'foo' => (is => 'ro');

    package Bar;

    use Moo;
    use MooX::Types::MooseLike::Base 'InstanceOf';

    has 'foo' => (is => 'ro', isa => InstanceOf['Foo']);

    package Baz;

    use Moo;
    use MooX::Types::MooseLike::Base 'InstanceOf';

    has 'bar' => (is => 'ro', isa => InstanceOf['Bar']);

    package main;

    subtest 'load inline packages Foo, Bar and Baz' => sub {
        my $wire = Beam::Wire->new(
            config => {
                foo => {
                    class => 'Foo',
                    args  => {
                        foo => 'Hello, World',
                    },
                },
                bar => {
                    class => 'Bar',
                    args  => {
                        foo => { '$ref' => 'foo' },
                    },
                },
                baz => {
                    class => 'Baz',
                    args  => {
                        bar => { '$ref' => 'bar' },
                    },
                },
            },
        );

        my ($foo, $bar, $baz);
        lives_ok { $foo = $wire->get( 'foo' ) };
        isa_ok $foo, 'Foo';
        is $foo->foo, 'Hello, World';
        lives_ok { $bar = $wire->get( 'bar' ) };
        isa_ok $bar, 'Bar';
        isa_ok $bar->foo, 'Foo';
        is $bar->foo->foo, 'Hello, World';
        lives_ok { $baz = $wire->get( 'baz' ) };
        isa_ok $baz, 'Baz';
        isa_ok $baz->bar, 'Bar';
        isa_ok $baz->bar->foo, 'Foo';
        is $baz->bar->foo->foo, 'Hello, World';
    };

}

done_testing;
