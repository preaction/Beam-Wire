
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

my $wire = Beam::Wire->new( file => $FILE );
isa_ok $wire->get('foo'), 'Foo';
my $obj = $wire->get('foo');
is refaddr $wire->get('foo'), refaddr $obj, 'container caches the object';
isa_ok $wire->get('foo')->bar, 'Bar', 'container injects Bar object';
is refaddr $wire->get('bar'), refaddr $wire->get('foo')->bar, 'container caches Bar object';
is $wire->get('bar')->text, "Hello, World", 'container gives bar text value';

done_testing;
