
use Test::More;
use Test::Deep;
use FindBin qw( $Bin );
use Path::Tiny qw( path );
use Scalar::Util qw( refaddr );

use Beam::Wire;

{
    package Foo;
    use Moo;
    has 'bar' => (
        is      => 'ro',
        isa     => sub { $_[0]->isa('Bar') },
    );
}

{
    package Bar;
    use Moo;
    has text => (
        is      => 'ro',
    );
}

{
    package Buzz;
    use Moo;
    has aref => (
        is      => 'ro',
    );
    sub BUILDARGS {
        my ( $class, $aref ) = @_;
        return { aref => $aref };
    }
}

{
    package Fizz;
    use Moo;
    has href => (
        is      => 'ro',
    );
}
$INC{"$_.pm"} = __FILE__ for qw( Foo Bar Buzz Fizz );


my @paths = map {; $_, "$_" }
            map { path( $Bin, 'share', $_ ) }
            qw( file.json file.pl file.yml )
            ;

for my $path ( @paths ) {
    subtest "load module from config - $path " . ref($path) => sub {
        my ( $ext ) = $path =~ /[.]([^.]+)$/;
        if ( $ext eq 'json' && !eval { require JSON; 1 } ) {
            pass "Can't load json for config: $@";
            return;
        }

        my $wire = Beam::Wire->new( file => $path );
        my $foo = $wire->get('foo');
        isa_ok $foo, 'Foo';
        is refaddr $wire->get('foo'), refaddr $foo, 'container caches the object';
        isa_ok $wire->get('foo')->bar, 'Bar', 'container injects Bar object';
        is refaddr $wire->get('bar'), refaddr $foo->bar, 'container caches Bar object';
        is $wire->get('bar')->text, "Hello, World", 'container gives bar text value';

        my $buzz = $wire->get( 'buzz' );
        isa_ok $buzz, 'Buzz', 'container gets buzz object';
        is refaddr $wire->get('buzz'), refaddr $buzz, 'container caches the object';
        cmp_deeply $buzz->aref, [qw( one two three )], 'container gives array of arrayrefs';

        my $fizz = $wire->get( 'fizz' );
        isa_ok $fizz, 'Fizz', 'container gets Fizz object';
        is refaddr $wire->get('fizz'), refaddr $fizz, 'container caches the object';
        cmp_deeply $fizz->href, { one => 'two' }, 'container gives hashref';
    };
}

done_testing;
