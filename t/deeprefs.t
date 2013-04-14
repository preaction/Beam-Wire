
use Test::Most;
use FindBin qw( $Bin );
use File::Spec::Functions qw( catdir );
use lib catdir( $Bin , 'lib' );
use Beam::Wire;

subtest 'load module from refs' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'Foo',
                args  => {
                    foo => {
                        ref  => 'config',
                        path => '//en/greeting'
                    }
                },
            },
            config => {
                value => {
                    en => {
                        greeting => 'Hello, World'
                    }
                }
            }
        },
    );

    my $foo;
    lives_ok { $foo = $wire->get( 'foo' ) };
    isa_ok $foo, 'Foo';
    is $foo->foo, 'Hello, World';

    # NEED MORE TESTS !!!
};

done_testing;
