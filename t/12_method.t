
use Test::Most;
use Scalar::Util qw( refaddr );

use Beam::Wire;

{
    package Foo;
    use Moo;
    has 'text' => (
        is      => 'rw',
    );
    has 'cons_called' => (
        is       => 'ro',
    );
    sub cons {
      my ( $class, @args ) = @_;
      return $class->new( cons_called => 1, @args );
    }
    sub append {
        my ( $self, $text ) = @_;
        $self->text( join "; ", $self->text, $text );
        return;
    }
    sub chain {
        my ( $self, %args ) = @_;
        return $self->new( text => join "; ", $self->text, $args{text} );
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

subtest 'multi method' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'Foo',
                method => [
                    {
                        method => 'new',
                        args => { text => 'new' },
                    },
                    {
                        method => 'append',
                        args => 'append',
                    },
                ],
            },
        },
    );
    my $foo = $wire->get( 'foo' );
    is $foo->text, 'new; append';
};

subtest 'chain method' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'Foo',
                method => [
                    {
                        method => 'new',
                        args => { text => 'new' },
                    },
                    {
                        method => 'chain',
                        return => 'chain',
                        args => { text => 'chain' },
                    },
                ],
            },
        },
    );
    my $foo = $wire->get( 'foo' );
    is $foo->text, 'new; chain';
};

done_testing;
