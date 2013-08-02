
use Test::Most;
use Beam::Wire;

subtest "get a service that doesn't exist" => sub {
    my $wire = Beam::Wire->new;
    throws_ok { $wire->get( 'foo' ) } 'Beam::Wire::Exception::NotFound';
    is $@->name, 'foo';
};

subtest "extend a service that doesn't exist" => sub {
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                extends => 'bar',
            },
        },
    );
    throws_ok { $wire->get( 'foo' ) } 'Beam::Wire::Exception::NotFound';
    is $@->name, 'bar';
};

subtest "service with both value and class/extends" => sub {
    subtest "class + value" => sub {
        my $wire;
        lives_ok {
            $wire = Beam::Wire->new(
                config => {
                    foo => {
                        class => 'Foo',
                        value => 'foo',
                    }
                }
            );
        };
        throws_ok { $wire->get( 'foo' ) } 'Beam::Wire::Exception::InvalidConfig';
        is $@->name, 'foo';
    };
    subtest "extends + value" => sub {
        my $wire;
        lives_ok {
            $wire = Beam::Wire->new(
                config => {
                    bar => {
                        value => 'bar',
                    },
                    foo => {
                        extends => 'bar',
                        value => 'foo',
                    }
                }
            );
        };
        throws_ok { $wire->get( 'foo' ) } 'Beam::Wire::Exception::InvalidConfig';
        is $@->name, 'foo';
    };
    subtest "value in extended service" => sub {
        my $wire;
        lives_ok {
            $wire = Beam::Wire->new(
                config => {
                    bar => {
                        value => 'bar',
                    },
                    foo => {
                        extends => 'bar',
                        class => 'foo',
                    }
                }
            );
        };
        throws_ok { $wire->get( 'foo' ) } 'Beam::Wire::Exception::InvalidConfig';
        is $@->name, 'foo';
    };
};

done_testing;
