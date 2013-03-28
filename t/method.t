
use Test::Most;
use FindBin qw( $Bin );
use File::Spec::Functions qw( catfile );
use Scalar::Util qw( refaddr );

use Beam::Wire;

{
    package Foo;
    use Moo;
    has 'text' => (
        is      => 'ro',
    );
    has 'cons_called' => (
        is       => 'ro',
    );
    sub cons {
      my ( $class, @args ) = @_;
      return $class->new( cons_called => 1, @args );
    }
}

subtest 'method' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'Foo',
                method => 'cons',
                args => {
                    text => 'Hello',
                },
            },
        },
    );

    my $foo = $wire->get( 'foo' );
    isa_ok $foo, 'Foo';
    is $foo->cons_called, 1, 'cons was called, not new';
    is $foo->text, 'Hello', 'args were passed';
};

done_testing;
