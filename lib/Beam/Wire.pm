# ABSTRACT: A Dependency Injection Container

package Beam::Wire;

use strict;
use warnings;

# VERSION

use Moo;
use Config::Any;
use Class::Load qw( load_class );
use File::Basename qw( dirname );
use File::Spec::Functions qw( catfile );
use MooX::Types::MooseLike::Base qw( :all );
use YAML::Any qw( LoadFile );

=head1 SYNOPSIS

    # wire.yml

    dbh:
        class: 'DBI'
        method: connect
        args:
            - 'dbi:mysql:dbname'
            - {
                PrintError: 1
              }

    # myscript.pl

    use Beam::Wire;

    my $wire = Beam::Wire->new( file => 'wire.yml' );
    my $dbh  = $wire->get( 'dbh' );
               $wire->set( 'dbh' => DBI->new( 'dbi:pgsql:dbname' ) );

=head1 DESCRIPTION

Beam::Wire is a dependency injection (DI) container. A DI (dependency injection)
container is a framework/mechanism where dependency creation and instantiation is
handled automatically (e.g. creates instances of classes that implement a given
dependency interface on request). DI does not require a container, in-fact, DI
without a container is possible and simply infers that dependency creation isn't
automatically handled for you (i.e. you have to write code to instantiate the
dependencies manually).

Dependency injection (DI) at it's core is about creating loosely coupled code by
separating construction logic from application logic. This is done by pushing
the creation of services (dependencies) to the entry point(s) and writing the
application logic so that dependencies are provided for its components. The
application logic doesn't know or care how it is supplied with its dependencies;
it just requires them and therefore receives them.

=head1 OVERVIEW

Beam::Wire loads a configuration L<file> and stores the specified configuration
in the L<config> attribute which is used to resolve it's services. This section
will give you an overview of how to declare dependencies and services, and shape
your configuration file.

=head2 WHAT IS A DEPENDENCY?

A dependency is a declaration of a component requirement. In layman's terms, a
dependency is a class attribute (or any value required for class construction)
which will likely be used to define services.

=head2 WHAT IS A SERVICE?

A service is a resolvable interface which may be selected and implemented on
behalf of a dependent component, or instantiated and returned per request. In
layman's terms, a service is a class configuration which can be used
independently or as a dependent of other services.

=head2 HOW ARE SERVICES CONFIGURED?

    # databases.yml

    production_db:
        class: 'DBI'
        method: connect
        args:
            - 'dbi:mysql:master'
            - { PrintError: 0, RaiseError: 0 }
    production_cache:
        class: 'CHI'
        args:
            driver: 'DBI'
            dbh: { ref: 'production_db' }
    development_db:
        class: 'DBI'
        method: connect
        args:
            - 'dbi:mysql:slave'
            - { PrintError: 1, RaiseError: 1 }
    development_cache:
        class: 'CHI'
        args:
            driver: 'DBI'
            dbh: { ref: 'development_db' }

=head3 Service Attributes

=head4 class

The class to instantiate. The class will be loaded and the C<method> (below)
method called.

=head4 method

The class method to call to construct the object. Defaults to C<new>.

=head4 args

The arguments to the C<method> method. This can be either an array or a hash,
like so:

    # array
    dbh:
        class: DBI
        method: connect
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

    # arrayrefs of hashrefs
    cache:
        class: CHI
        args:
            -   driver: Memory
                max_size: 16MB

=head3 Inner Containers

Beam::Wire objects can hold other Beam::Wire objects!

    inner:
        class: Beam::Wire
        args:
            config:
                dbh:
                    class: DBI
                    method: connect
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

=head3 Inner Files

    inner:
        class: Beam::Wire
        args:
            file: inner.yml

Inner containers can be created by reading files just like the main container.
If the C<file> attribute is relative, the parent's C<dir> attribute will be
added:

    # share/parent.yml
    inner:
        class: Beam::Wire
        args:
            file: inner.yml

    # share/inner.yml
    dbh:
        class: DBI
        method: connect
        args:
            - 'dbi:sqlite:data.db'

    # myscript.pl
    use Beam::Wire;

    my $container = Beam::Wire->new(
        file => 'share/parent.yml',
    );

    my $dbh = $container->get( 'inner/dbh' );

If more control is needed, you can set the L<dir> attribute on the parent
container. If even more control is needed, you can make a subclass of Beam::Wire.

=cut

=attribute file

The file attribute contains the file path of the file where Beam::Wire container
services are configured (typically a YAML file). The file's contents should form
a single hashref. The keys will become the service names.

=cut

has file => (
    is      => 'ro',
    isa     => Str,
);

=attribute dir

The dir attribute contains the directory path to use when searching for inner
container files. Defaults to the directory which contains the file specified by
the L<file> attribute.

=cut

has dir => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    default => sub {
        dirname $_[0]->file;
    },
);

=attribute config

The config attribute contains a hashref of service configurations. This data is
loaded by L<Config::Any> using the file specified by the L<file> attribute.

=cut

has config => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => 1
);

sub _build_config {
    my ( $self ) = @_; local $Config::Any::YAML::NO_YAML_XS_WARNING = 1;
    my $loader = Config::Any->load_files( {
        files  => [$self->file], use_ext => 1, flatten_to_hash => 1
    } );
    return "HASH" eq ref $loader ? (values(%{$loader}))[0] : {};
}

=attribute services

A hashref of services. If you have any services already built, add them here.

=cut

has services => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

=method get

The get method resolves and returns the specified service.

=cut

sub get {
    my ( $self, $name ) = @_;
    if ( $name =~ '/' ) {
        my ( $container_name, $service ) = split m{/}, $name, 2;
        my $container = $self->services->{$container_name} ||=
            $self->create_service( %{ $self->config->{$container_name} } )
        ;
        return $container->get( $service );
    }
    return $self->services->{$name}
        ||= $self->create_service( %{ $self->config->{$name} } );
}

=method set

The set method configures and stores the specified service.

=cut

sub set {
    my ( $self, $name, $service ) = @_;
    if ( $name =~ '/' ) {
        my ( $container_name, $service_name ) = split m{/}, $name, 2;
        return $self->get( $container_name )->set( $service_name, $service );
    }
    $self->services->{$name} = $service;
}

sub parse_args {
    my ( $self, %service_info ) = @_;
    return if not exists $service_info{args};
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
    if ( $service_info{class}->isa( 'Beam::Wire' ) ) {
        my %args = @args;
        # Subcontainers cannot scan for refs in their configs
        my $config = delete $args{config};
        # Relative subcontainer files should be from the current
        # container's directory
        if ( exists $args{file} && $args{file} !~ m{^/} ) {
            $args{file} = catfile( $self->dir, $args{file} );
        }
        @args = $self->find_refs( %args );
        if ( $config ) {
            push @args, config => $config;
        }
    }
    else {
        @args = $self->find_refs( @args );
    }
    return @args;
}

sub create_service {
    my ( $self, %service_info ) = @_;
    my @args = $self->parse_args( %service_info );
    load_class( $service_info{class} );
    my $method = $service_info{method} || "new";
    return $service_info{class}->$method( @args );
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

=method new

Create a new container.

=cut

1;
