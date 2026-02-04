
use Test::More;
use Test::Deep;
use Test::Exception;
use Test::Lib;
use Beam::Wire;

subtest 'class version ok' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'My::ArgsTest',
                version => '0.001',
            },
        },
    );

    my $foo;
    lives_ok { $foo = $wire->get( 'foo' ) } 'required version is less than VERSION';
    is $wire->get_config( 'foo' )->{ version }, '0.001', 'required version';
    is $foo->VERSION, '0.002', 'VERSION';
    cmp_deeply $foo->got_args, [ ];
};

subtest 'class version not ok' => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                class => 'My::ArgsTest',
                version => '0.003',
            },
        },
    );

    my $foo;
    dies_ok { $foo = $wire->get( 'foo' ) } 'required version is greater than VERSION';
    is $foo, undef;
};

done_testing;
