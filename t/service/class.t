
use Test::More;
use Test::Exception;
use Test::Lib;
use Beam::Wire;

{
  package ResolveClass;
  use Moo::Role;

  around 'resolve_class' => sub {
    my $orig = shift;
    return 'My::' . $_[1];
  }
}


subtest 'class with name resolver' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'ClassTest',
                args => { foo => bar },
            },
        },
    );

    Moo::Role->apply_roles_to_object( $wire, 'ResolveClass' );

    my $foo;
    lives_ok { $foo = $wire->get( 'foo' ) };
    is $foo->foo, 'bar';
};

done_testing;
