
use Test::More;
use Test::Deep;
use Test::Exception;
use Test::Lib;
use Beam::Wire;
use Moo::Role ();

subtest 'compose a single role' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'My::ArgsTest',
                with => 'My::ArgsListRole',
                args => {
                    foo => 'bar',
                },
            },
        },
    );

    my $svc;
    lives_ok { $svc = $wire->get( 'foo' ) };
    isa_ok $svc, 'My::ArgsTest';
    ok $svc->DOES( 'My::ArgsListRole' );
    cmp_deeply [ $svc->got_args_list ], [ foo => 'bar' ];
};

subtest 'compose multiple roles' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'My::ArgsTest',
                with => [
                    'My::ArgsListRole',
                    'My::CloneRole',
                ],
                args => {
                    foo => 'bar',
                },
            },
        },
    );

    my $svc;
    lives_ok { $svc = $wire->get( 'foo' ) };
    isa_ok $svc, 'My::ArgsTest';
    ok $svc->DOES( 'My::ArgsListRole' );
    ok $svc->DOES( 'My::CloneRole' );
    cmp_deeply [ $svc->got_args_list ], [ foo => 'bar' ];
    ok $svc->can( 'clone' );
};


{
  package ResolveRole;
  use Moo::Role;

  around 'resolve_role' => sub {
    my $orig = shift;
    return 'My::' . $_[1];
  }
}

subtest 'compose a single role with name resolver' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'My::ArgsTest',
                with => 'ArgsListRole',
            },
        },
    );

    Moo::Role->apply_roles_to_object( $wire, 'ResolveRole' );

    my $svc;
    lives_ok { $svc = $wire->get( 'foo' ) };
    isa_ok $svc, 'My::ArgsTest';
    ok $svc->DOES( 'My::ArgsListRole' );
};

subtest 'compose multiple roles with name resolver' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'My::ArgsTest',
                with => [
                    'ArgsListRole',
                    'CloneRole',
                ],
            },
        },
    );

    Moo::Role->apply_roles_to_object( $wire, 'ResolveRole' );

    my $svc;
    lives_ok { $svc = $wire->get( 'foo' ) };
    isa_ok $svc, 'My::ArgsTest';
    ok $svc->DOES( 'My::ArgsListRole' );
    ok $svc->DOES( 'My::CloneRole' );
};
done_testing;
