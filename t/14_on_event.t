
use Test::More;
use Test::Exception;
use Test::Lib;
use Beam::Wire;

subtest 'single event listener' => sub {
    my $wire = Beam::Wire->new(
        config => {
            emitter => {
                class => 'My::Emitter',
                on => {
                    greet => {
                        '$ref' => 'listener',
                        '$method' => 'on_greet',
                    },
                },
            },
            listener => {
                class => 'My::Listener',
            },
        },
    );

    my $svc;
    lives_ok { $svc = $wire->get( 'emitter' ) };
    isa_ok $svc, 'My::Emitter';

    $svc->emit( 'greet' );
    is $wire->get( 'listener' )->events_seen, 1;
};

subtest 'multiple event listeners' => sub {
    my $wire = Beam::Wire->new(
        config => {
            emitter => {
                class => 'My::Emitter',
                on => {
                    greet => [
                        {
                            '$ref' => 'listener',
                            '$method' => 'on_greet',
                        },
                        {
                            '$ref' => 'other_listener',
                            '$method' => 'on_greet',
                        },
                    ],
                },
            },
            listener => {
                class => 'My::Listener',
            },
            other_listener => {
                class => 'My::Listener',
            },
        },
    );

    my $svc;
    lives_ok { $svc = $wire->get( 'emitter' ) };
    isa_ok $svc, 'My::Emitter';

    $svc->emit( 'greet' );
    is $wire->get( 'listener' )->events_seen, 1;
    is $wire->get( 'other_listener' )->events_seen, 1;
};

done_testing;
