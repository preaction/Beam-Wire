
use Test::More;
use Test::Exception;
use Test::Lib;
use Scalar::Util qw( refaddr );
use Beam::Wire;

subtest 'value service: simple scalar' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'My::RefTest',
                args  => {
                    got_ref => { '$ref' => 'greeting' }
                },
            },
            greeting => {
                value => 'Hello, World'
            }
        },
    );

    my $greeting;
    lives_ok { $greeting = $wire->get( 'greeting' ) };
    ok !ref $greeting, 'got a simple scalar';
    is $greeting, 'Hello, World';

    my $foo;
    lives_ok { $foo = $wire->get( 'foo' ) };
    isa_ok $foo, 'My::RefTest';
    is $foo->got_ref, 'Hello, World';
};

subtest 'get() override factory (anonymous services)' => sub {
    my $wire = Beam::Wire->new(
        config => {
            bar => {
                class => 'My::ArgsTest',
            },
            foo => {
                class => 'My::RefTest',
                args => {
                    got_ref => { '$ref' => "bar" },
                },
            },
        },
    );
    my $foo = $wire->get( 'foo' );
    my $oof = $wire->get( 'foo', args => { got_ref => My::ArgsTest->new( text => 'New World' ) } );
    isnt refaddr $oof, refaddr $foo, 'get() with overrides creates a new object';
    isnt refaddr $oof, refaddr $wire->get('foo'), 'get() with overrides does not save the object';
    isnt refaddr $oof->got_ref, refaddr $foo->got_ref, 'our override gave our new object a new bar';
};

subtest 'dies when service not found' => sub {
    my $wire = Beam::Wire->new;
    dies_ok { $wire->get( 'foo' ) };
};

done_testing;
