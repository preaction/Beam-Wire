
use Test::More;
use Test::Deep;
use FindBin qw( $Bin );
use Path::Tiny qw( path );
use Scalar::Util qw( refaddr );

my $SINGLE_FILE = path( $Bin, '..', 'share', 'file.yml' );
my $DEEP_FILE   = path( $Bin, '..', 'share', 'inner_inline.yml' );
my $INNER_FILE  = path( $Bin, '..', 'share', 'inner_file.yml' );

use Beam::Wire;

{
    package Foo;
    use Moo;
    has 'bar' => (
        is      => 'ro',
        isa     => sub { $_[0]->isa('Bar') },
    );
}
local $INC{"Foo.pm"} = __FILE__;

{
    package Bar;
    use Moo;
    has text => (
        is      => 'ro',
    );
}
local $INC{"Bar.pm"} = __FILE__;

subtest 'container in services' => sub {
    my $wire = Beam::Wire->new(
        services => {
            container => Beam::Wire->new( file => $SINGLE_FILE ),
        },
    );

    my $foo = $wire->get( 'container/foo' );
    isa_ok $foo, 'Foo';
    my $obj = $wire->get('container/foo');
    is refaddr $foo, refaddr $obj, 'container caches the object';
    isa_ok $foo->bar, 'Bar', 'container injects Bar object';
    is refaddr $wire->get('container/bar'), refaddr $foo->bar, 'container caches Bar object';
    is $wire->get('container/bar')->text, "Hello, World", 'container gives bar text value';
};

subtest 'container in file' => sub {
    my $wire = Beam::Wire->new(
        file => $DEEP_FILE,
    );

    my $foo = $wire->get( 'inline_container/foo' );
    isa_ok $foo, 'Foo';
    is refaddr $foo, refaddr $wire->get('inline_container/foo'), 'container caches the object';
    isa_ok $foo->bar, 'Bar', 'container injects Bar object';
    is refaddr $wire->get('inline_container/bar'), refaddr $foo->bar, 'container caches Bar object';
    is $wire->get('inline_container/bar')->text, "Hello, World", 'container gives bar text value';

    my $fizz = $wire->get( 'service_container/fizz' );
    isa_ok $fizz, 'Foo';
    is refaddr $fizz, refaddr $wire->get('service_container/fizz'), 'container caches the object';
    isa_ok $fizz->bar, 'Bar', 'container injects Bar object';
    is refaddr $fizz->bar, refaddr $foo->bar, 'fizz takes the same bar as foo';
    is refaddr $wire->get('inline_container/bar'), refaddr $fizz->bar, 'container caches Bar object';
    is $wire->get('service_container/buzz')->text, "Hello, Buzz", 'container gives bar text value';
};

subtest 'set inside subcontainer' => sub {
    my $wire = Beam::Wire->new(
        services => {
            container => Beam::Wire->new( file => $SINGLE_FILE ),
        },
    );

    my $fizz = Foo->new( bar => $wire->get('container/bar' ) );
    $wire->set( 'container/fizz' => $fizz );

    my $foo = $wire->get( 'container/fizz' );
    isa_ok $foo, 'Foo';
    my $obj = $wire->get('container/fizz');
    is refaddr $foo, refaddr $obj, 'container caches the object';
    isa_ok $foo->bar, 'Bar', 'container injects Bar object';
    is refaddr $wire->get('container/bar'), refaddr $foo->bar, 'container caches Bar object';
    is $wire->get('container/bar')->text, "Hello, World", 'container gives bar text value';
};

subtest 'inner container file' => sub {
    my $wire = Beam::Wire->new(
        file => $INNER_FILE,
    );

    my $foo = $wire->get( 'container/foo' );
    isa_ok $foo, 'Foo';
    my $obj = $wire->get('container/foo');
    is refaddr $foo, refaddr $obj, 'container caches the object';
    isa_ok $foo->bar, 'Bar', 'container injects Bar object';
    is refaddr $wire->get('container/bar'), refaddr $foo->bar, 'container caches Bar object';
    is $wire->get('container/bar')->text, "Hello, World", 'container gives bar text value';
};

subtest 'inner container get() overrides' => sub {
    my $wire = Beam::Wire->new(
        file => $INNER_FILE,
    );

    my $foo = $wire->get( 'container/foo' );
    my $oof = $wire->get( 'container/foo', args => { bar => Bar->new( text => 'New World' ) } );
    isnt refaddr $oof, refaddr $foo, 'get() with overrides creates a new object';
    isnt refaddr $oof, refaddr $wire->get('container/foo'), 'get() with overrides does not save the object';
    isnt refaddr $oof->bar, refaddr $foo->bar, 'our override gave our new object a new bar';
};

subtest 'inner extends' => sub {
    my $wire = Beam::Wire->new(
        config => {
            inner => {
                class => 'Beam::Wire',
                args => { file => $SINGLE_FILE },
            },
            foo => {
                extends => 'inner/foo',
            },
        },
    );
    my $foo = $wire->get( 'foo' );
    isa_ok $foo, 'Foo';
    is refaddr $foo, refaddr $wire->get('foo'), 'container caches the object';
    isa_ok $foo->bar, 'Bar', 'container injects Bar object';
    is refaddr $wire->get('inner/bar'), refaddr $foo->bar, 'container caches Bar object';
    is $wire->get('inner/bar')->text, "Hello, World", 'container gives bar text value';
};

subtest 'inner get_config' => sub {
    my $wire = Beam::Wire->new(
        config => {
            inner => {
                class => 'Beam::Wire',
                args => { file => $SINGLE_FILE },
            },
            foo => {
                extends => 'inner/foo',
            },
        },
    );
    my $config = $wire->get_config( 'inner/foo' );
    cmp_deeply $config, { class => 'Foo', args => { bar => { '$ref' => 'inner/bar' } } } or diag explain $config;
};




done_testing;
