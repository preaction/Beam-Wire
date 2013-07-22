
use Test::Most;
use Scalar::Util qw( refaddr );
use Beam::Wire;

{
    package Foo;
    use Moo;
    has 'bar' => (
        is      => 'ro',
        isa     => sub { $_[0]->isa('Bar') },
    );
}

{
    package Bar;
    use Moo;
    has text => (
        is      => 'ro',
    );
}

subtest 'get() override factory (anonymous services)' => sub {
    my $wire = Beam::Wire->new(
        config => {
            bar => {
                class => 'Bar',
            },
            foo => {
                class => 'Foo',
                args => {
                    bar => { '$ref' => "bar" },
                },
            },
        },
    );
    my $foo = $wire->get( 'foo' );
    my $oof = $wire->get( 'foo', args => { bar => Bar->new( text => 'New World' ) } );
    isnt refaddr $oof, refaddr $foo, 'get() with overrides creates a new object';
    isnt refaddr $oof, refaddr $wire->get('foo'), 'get() with overrides does not save the object';
    isnt refaddr $oof->bar, refaddr $foo->bar, 'our override gave our new object a new bar';
};

done_testing;
