
use Test::Most;
use FindBin qw( $Bin );
use File::Spec::Functions qw( catdir );
use lib catdir( $Bin , 'lib' );
use Beam::Wire;

subtest 'load module from raw values' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'Foo',
                args  => {
                    foo => { ref => 'greeting' }
                },
            },
            greeting => {
                value => 'Hello, World'
            }
        },
    );

    my $greeting;
    lives_ok { $greeting = $wire->get( 'greeting' ) };
    is ref $greeting, '', 'got a simple scalar';
    is $greeting, 'Hello, World';

    my $foo;
    lives_ok { $foo = $wire->get( 'foo' ) };
    isa_ok $foo, 'Foo';
    is $foo->foo, 'Hello, World';
};

done_testing;
