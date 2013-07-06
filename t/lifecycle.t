
use Test::Most;
use FindBin qw( $Bin );
use File::Spec::Functions qw( catdir );
use Scalar::Util qw( refaddr );
use lib catdir( $Bin , 'lib' );
use Beam::Wire;

subtest 'singleton lifecycle' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'Foo',
                lifecycle => 'singleton',
            },
            bar => {
                class => 'Foo',
                args => {
                    foo => { '$ref' => 'foo' },
                },
            },
        },
    );

    my $foo = $wire->get('foo');
    isa_ok $foo, 'Foo';
    my $oof = $wire->get('foo');
    is refaddr $oof, refaddr $foo, 'same foo object is returned';
    my $bar = $wire->get('bar');
    is refaddr $bar->foo, refaddr $foo, 'same foo object is given to bar';
};

subtest 'factory lifecycle' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'Foo',
                lifecycle => 'factory',
            },
            bar => {
                class => 'Foo',
                args => {
                    foo => { '$ref' => 'foo' },
                },
            },
        },
    );

    my $foo = $wire->get('foo');
    isa_ok $foo, 'Foo';
    my $oof = $wire->get('foo');
    isnt refaddr $oof, refaddr $foo, 'different foo object is returned';
    my $bar = $wire->get('bar');
    isnt refaddr $bar->foo, refaddr $foo, 'different foo object is given to bar';
    isnt refaddr $bar->foo, refaddr $oof, 'different foo object is given to bar';
};

subtest 'eager lifecycle' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'Foo',
            },
            bar => {
                class => 'Foo',
                lifecycle => 'eager',
                args => {
                    foo => { '$ref' => 'foo' },
                },
            },
        },
    );

    my $bar = $wire->services->{bar};
    isa_ok $bar, 'Foo', 'bar exists without calling get()';
    is refaddr $bar->foo, refaddr $wire->get('foo'),
        'foo is also created, because bar depends on foo';
};

subtest 'default lifecycle is singleton' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'Foo',
            },
            bar => {
                class => 'Foo',
                args => {
                    foo => { '$ref' => 'foo' },
                },
            },
        },
    );

    my $foo = $wire->get('foo');
    isa_ok $foo, 'Foo';
    my $oof = $wire->get('foo');
    is refaddr $oof, refaddr $foo, 'same foo object is returned';
    my $bar = $wire->get('bar');
    is refaddr $bar->foo, refaddr $foo, 'same foo object is given to bar';
};

done_testing;
