
use Test::Most;
use FindBin qw( $Bin );
use File::Spec::Functions qw( catfile );
use Scalar::Util qw( refaddr );

my $FILE = catfile( $Bin, 'file.yml' );

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

my $wire = Beam::Wire->new( file => $FILE );
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

my $fizzbuzz = $wire->get( 'fizzbuzz' );
isa_ok $fizzbuzz, 'Buzz', 'container gets buzz object';
is refaddr $wire->get('fizzbuzz'), refaddr $fizzbuzz, 'container caches the object';
cmp_deeply $fizzbuzz->aref, "Hello", 'container gives simple scalar';

done_testing;
