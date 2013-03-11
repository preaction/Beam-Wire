package Beam::Wire;

use strict;
use warnings;

use Moo;
use MooX::Types::MooseLike::Base qw( :all );
use YAML::Any qw( LoadFile );

has file => (
    is      => 'ro',
    isa     => Str,
);

has config => (
    is          => 'ro',
    isa         => HashRef,
    lazy        => 1,
    default     => sub { LoadFile( $_[0]->file ); },
);

has services => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

sub get {
    my ( $self, $name ) = @_;
    if ( $name =~ '/' ) {
        my ( $container_name, $service ) = split m{/}, $name, 2;
        my $container = $self->services->{$container_name}
                      ||= $self->create_service( %{ $self->config->{$container_name} } );
        return $container->get( $service );
    }
    return $self->services->{$name} 
        ||= $self->create_service( %{ $self->config->{$name} } );
}

sub set {
    my ( $self, $name, $service ) = @_;
    if ( $name =~ '/' ) {
        my ( $container_name, $service_name ) = split m{/}, $name, 2;
        return $self->get( $container_name )->set( $service_name, $service );
    }
    $self->services->{$name} = $service;
}

sub create_service {
    my ( $self, %service_info ) = @_;
    my @args;
    if ( ref $service_info{args} eq 'ARRAY' ) {
        @args = @{$service_info{args}};
    }
    elsif ( ref $service_info{args} eq 'HASH' ) {
        @args = %{$service_info{args}};
    }
    else {
        # Try anyway?
        @args = $service_info{args};
    }
    # Subcontainers cannot scan for refs in their configs
    if ( $service_info{class}->isa( 'Beam::Wire' ) ) {
        my %args = @args;
        my $config = delete $args{config};
        @args = $self->find_refs( %args );
        if ( $config ) {
            push @args, config => $config;
        }
    }
    else {
        @args = $self->find_refs( @args );
    }
    return $service_info{class}->new( @args );
}

sub find_refs {
    my ( $self, @args ) = @_;
    my @out;
    for my $arg ( @args ) {
        if ( ref $arg eq 'HASH' ) {
            # Detect references
            my @keys = keys %$arg;
            if ( @keys == 1 && $keys[0] eq 'ref' ) {
                my $name = $arg->{ref};
                # Found a ref!
                push @out, $self->get( $name );
            }
            else {
                push @out, { $self->find_refs( %$arg ) };
            }
        }
        elsif ( ref $arg eq 'ARRAY' ) {
            push @out, [ map { $self->find_refs( $_ ) } @$arg ];
        }
        else {
            push @out, $arg; # simple scalars
        }
    }
    return @out;
}

1;
__END__

=head1 NAME

Beam::Wire - A Dependency Injection Container

=head1 SYNOPSIS

    # wire.yml
    dbh:
        class: 'DBI'
        args:
            - 'dbi:mysql:dbname'
            - {
                PrintError: 1
              }
    cache:
        class: 'CHI'
        args:
            driver: 'DBI'
            dbh: { ref: 'dbh' }

    # myscript.pl
    use Beam::Wire;
    my $wire  = Beam::Wire->new( file => 'wire.yml' );
    my $dbh   = $wire->get( 'dbh' );
    my $cache = $wire->get( 'cache' );

    $wire->set( 'dbh', DBI->new( 'dbi:pgsql:dbname' ) );

=head1 DESCRIPTION

Beam::Wire is a dependency injection container.

TODO: Explain what a DI container does and why you want it

=head1 ATTRIBUTES

=head2 file

Read the list of services from the given file. The file is described below in the L<FILE> section.

=head1 METHODS

=head2 new

Create a new container.

=head1 FILE

Beam::Wire can read a YAML file to fill a container with services. The file should be a single hashref.
The keys will be the service names.

=head1 SERVICE ATTRIBUTES

=head2 class

The class to instantiate. The class will be loaded and the C<new> method called.

=head2 args

The arguments to the C<new> method. This can be either an array or a hash, like so:

    # array
    dbh: 
        class: DBI
        args:
            - 'dbi:mysql:dbname'

    # hash
    cache:
        class: CHI
        args:
            driver: Memory
            max_size: 16MB

Using the array of arguments, you can give arrayrefs or hashrefs:

    # arrayref of arrayrefs
    names:
        class: 'Set::CrossProduct'
        args:
            -
                - [ 'Foo', 'Barkowictz' ]
                - [ 'Bar', 'Foosmith' ]
                - [ 'Baz', 'Bazleton' ]

    # hashref
    cache:
        class: CHI
        args:
            -   driver: Memory
                max_size: 16MB

=head1 INNER CONTAINERS

Beam::Wire objects can hold other Beam::Wire objects!

    inner:
        class: Beam::Wire
        args:
            config:
                dbh:
                    class: DBI
                    args:
                        - 'dbi:mysql:dbname'
                cache:
                    class: CHI
                    args:
                        driver: Memory
                        max_size: 16MB

Inner containers' contents can be reached from outer containers by separating
the names with a slash character:

    my $dbh = $wire->get( 'inner/dbh' );
