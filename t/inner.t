
use Test::Most;
use FindBin qw( $Bin );
use File::Spec::Functions qw( catfile );
use Scalar::Util qw( refaddr );

my $SINGLE_FILE = catfile( $Bin, 'file.yml' );
my $DEEP_FILE   = catfile( $Bin, 'inner_inline.yml' );
my $INNER_FILE  = catfile( $Bin, 'inner_file.yml' );

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


done_testing;
