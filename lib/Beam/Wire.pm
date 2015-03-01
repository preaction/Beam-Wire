package Beam::Wire;
# ABSTRACT: Lightweight Dependency Injection Container

use strict;
use warnings;

use Scalar::Util qw( blessed );
use Moo;
use Config::Any;
use Module::Runtime qw( use_module );
use Data::DPath qw ( dpath );
use Path::Tiny qw( path );
use File::Basename qw( dirname );
use File::Spec::Functions qw( splitpath catfile file_name_is_absolute );
use Types::Standard qw( :all );

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

Beam::Wire loads a configuration L<file|file> and stores the specified configuration
in the L<config|config attribute> which is used to resolve it's services. This section
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
            dbh: { $ref: 'production_db' }
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
            dbh: { $ref: 'development_db' }

=head3 Service Attributes

=head4 class

The class to instantiate. The class will be loaded and the C<method> (below)
method called.

=head4 method

The class method to call to construct the object. Defaults to C<new>.

If multiple methods are needed to initialize an object, C<method> can be an
arrayref of hashrefs, like so:

    my_service:
        class: My::Service
        method:
            - method: new
              args:
                foo: bar
            - method: set_baz
              args:
                - Fizz

In this example, first we call C<My::Service->new( foo => "bar" );> to get our
object, then we call C<$obj->set_baz( "Fizz" );> as a further initialization
step.

To chain methods together, add C<return: chain>:

    my_service:
        class: My::Service
        method:
            - method: new
              args:
                foo: bar
            - method: set_baz
              return: chain
              args:
                - Fizz
            - method: set_buzz
              return: chain
              args:
                - Bork

This example is equivalent to the following code:

    my $service = My::Service->new( foo => "bar" )->set_baz( "Fizz" )
                ->set_buzz( "Bork" );

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

=head4 extends

Inherit and override attributes from another service. 

    dbh:
        class: DBI
        method: connect
        args:
            - 'dbi:mysql:dbname'
    dbh_dev:
        extends: 'dbh'
        args:
            - 'dbi:mysql:devdb'

Hash C<args> will be merged seperately, like so:

    activemq:
        class: My::ActiveMQ
        args:
            host: example.com
            port: 61312
            user: root
            password: 12345
    activemq_dev:
        extends: 'activemq'
        args:
            host: dev.example.com

C<activemq_dev> will get the C<port>, C<user>, and C<password> arguments
from the base service C<activemq>.

=head4 lifecycle

Control how your service is created. The default value, C<singleton>, will cache
the resulting service and return it for every call to C<get()>. The other
value, C<factory>, will create a new instance of the service every time:

    today:
        class: DateTime
        method: today
        lifecycle: factory
        args:
            time_zone: US/Chicago
    report_yesterday:
        class: My::Report
        args:
            date: { $ref: today, $method: add, $args: [ "days", "-1" ] }
    report_today:
        class: My::Report
        args:
            date: { $ref: today }

C<DateTime->add> modifies the object and returns the newly-modified object (to
allow for method chaining.) Without C<lifecycle: factory>, the C<today> service
would become yesterday, making it hard to know what C<report_today> would
report on.

An C<eager> value will be created as soon as the container is created. If you
have an object that registers itself upon instantiation, you can make sure your
object is created as soon as possible by doing C<lifecycle: eager>.

=head4 on

Attach event listeners using L<Beam::Emitter|Beam::Emitter>.

    emitter:
        class: My::Emitter
        on:
            before_my_event:
                $ref: listener
                $method: on_before_my_event
            my_event:
                - $ref: listener
                  $method: on_my_event
                - $ref: other_listener
                  $method: on_my_event
    listener:
        class: My::Listener
    other_listener:
        class: My::Listener

Now, when the C<emitter> fires off its events, they are dispatched to the
appropriate listeners.

=head3 Config Services

A config service allows you to read a config file and use it as a service, giving
all or part of it to other objects in your container.

To create a config service, use the C<config> key. The value is the path to the
file to read. By default, YAML, JSON, XML, and Perl files are supported (via
L<Config::Any>).

    # db_config.yml
    dsn: 'dbi:mysql:dbname'
    user: 'mysql'
    pass: '12345'

    # container.yml
    db_config:
        config: db_config.yml

You can pass in the entire config to an object using C<$ref>:

    # container.yml
    db_config:
        config: db_config.yml
    dbobj:
        class: My::DB
        args:
            conf:
                $ref: db_config

If you only need the config file once, you can create an anonymous config
object.

    # container.yml
    dbobj:
        class: My::DB
        args:
            conf:
                $config: db_config.yml

The config file can be used as all the arguments to the service:

    # container.yml
    dbobj:
        class: My::DB
        args:
            $config: db_config.yml

In this example, the constructor will be called like:

    my $dbobj = My::DB->new(
        dsn => 'dbi:mysql:dbname',
        user => 'mysql',
        pass => '12345',
    );

You can reference individual items in a configuration hash using C<$path>
references:

    # container.yml
    db_config:
        config: db_config.yml
    dbh:
        class: DBI
        method: connect
        args:
            - $ref: db_config
              $path: /dsn
            - $ref: db_config
              $path: /user
            - $ref: db_config
              $path: /pass

B<NOTE:> You cannot use C<$path> and anonymous config objects.


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

If more control is needed, you can set the L<dir|dir attribute> on the parent
container. If even more control is needed, you can make a subclass of Beam::Wire.

=head3 Service/Configuration References

    chi:
        class: CHI
        args:
            driver: 'DBI'
            dbh: { $ref: 'dbh' }
    dbh:
        class: DBI
        method: connect
        args:
            - { $ref: dsn }
            - { $ref: usr }
            - { $ref: pwd }
    dsn:
        value: "dbi:SQLite:memory:"
    usr:
        value: "admin"
    pwd:
        value: "s3cret"

The reuse of service and configuration containers as arguments for other
services is encouraged so we have provided a means of referencing those objects
within your configuration. A reference is an arugment (a service argument) in
the form of a hashref with a C<$ref> key whose value is the name of another
service. Optionally, this hashref may contain a C<$path> key whose value is a
L<Data::DPath|Data::DPath> search string which should return the found data
structure from within the referenced service.

It is also possible to use raw-values as services, this is done by configuring a
service using a single key/value pair with a C<value> key whose value contains
the raw-value you wish to reuse.

=cut

=attr file

The file attribute contains the file path of the file where Beam::Wire container
services are configured (typically a YAML file). The file's contents should form
a single hashref. The keys will become the service names.

=cut

has file => (
    is      => 'ro',
    isa     => Str,
);

=attr dir

The dir attribute contains the directory path to use when searching for inner
container files. Defaults to the directory which contains the file specified by
the L<file|file attribute>.

=cut

has dir => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    default => sub {
        my ( $volume, $path, $file ) = splitpath( $_[0]->file );
        return join "", $volume, $path;
    },
);

=attr config

The config attribute contains a hashref of service configurations. This data is
loaded by L<Config::Any|Config::Any> using the file specified by the
L<file|file attribute>.

=cut

has config => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => 1
);

sub _build_config {
    my ( $self ) = @_;
    return {} if ( !$self->file );
    return $self->_load_config( $self->file );
}

=attr services

A hashref of services. If you have any services already built, add them here.

=cut

has services => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => 1,
);

sub _build_services {
    my ( $self ) = @_;
    my $services = {};
    return $services;
}

=attr meta_prefix

The character that begins a meta-property inside of a service's C<args>. This
includes C<$ref>, C<$path>, C<$method>, and etc...

The default value is '$'. The empty string is allowed.

=cut

has meta_prefix => (
    is      => 'ro',
    isa     => Str,
    default => sub { q{$} },
);

=method get( name, [ overrides ] )

The get method resolves and returns the service named C<name>.

C<overrides> may be a list of name-value pairs. If specified, get()
will create an anonymous service that extends the C<name> service
with the given config overrides:

    # test.pl
    use Beam::Wire;
    my $wire = Beam::Wire->new(
        config => {
            foo => {
                args => {
                    text => 'Hello, World!',
                },
            },
        },
    );
    my $foo = $wire->get( 'foo', args => { text => 'Hello, Chicago!' } );
    print $foo; # prints "Hello, Chicago!"

This allows you to create factories out of any service, overriding service
configuration at run-time.

=cut

sub get {
    my ( $self, $name, %override ) = @_;
    if ( $name =~ q{/} ) {
        my ( $container_name, $service ) = split m{/}, $name, 2;
        return $self->get( $container_name )->get( $service, %override );
    }
    if ( keys %override ) {
        return $self->create_service( "\$anonymous extends $name", %override, extends => $name );
    }
    my $service = $self->services->{$name};
    if ( !$service ) {
        my $config_ref = $self->get_config($name);
        unless ( $config_ref ) {
            Beam::Wire::Exception::NotFound->throw(
                name => $name,
                file => $self->file,
            );
        }
        my %config  = %{ $config_ref };
        $service = $self->create_service( $name, %config );
        if ( !$config{lifecycle} || lc $config{lifecycle} ne 'factory' ) {
            $self->services->{$name} = $service;
        }
    }
    return $service;
}

=method set

The set method configures and stores the specified service.

=cut

## no critic ( ProhibitAmbiguousNames )
# This was named set() before I started using Perl::Critic
sub set {
    my ( $self, $name, $service ) = @_;
    if ( $name =~ q{/} ) {
        my ( $container_name, $service_name ) = split m{/}, $name, 2;
        return $self->get( $container_name )->set( $service_name, $service );
    }
    $self->services->{$name} = $service;
    return;
}

=method get_config

Get the config with the given name, searching inner containers if required

=cut

sub get_config {
    my ( $self, $name ) = @_;
    if ( $name =~ q{/} ) {
        my ( $container_name, $service ) = split m{/}, $name, 2;
        my $inner_config = $self->get( $container_name )->get_config( $service );
        # Fix relative references to prefix the container name
        return { $self->fix_refs( $container_name, %{$inner_config} ) };
    }
    return $self->config->{$name};
}

# TODO: Refactor fix_refs and find_refs into an iterator
sub fix_refs {
    my ( $self, $container_name, @args ) = @_;
    my @out;
    my %meta = $self->get_meta_names;
    for my $arg ( @args ) {
        if ( ref $arg eq 'HASH' ) {
            if ( $self->is_meta( $arg ) ) {
                my %new = ();
                for my $key ( @meta{qw( ref extends )} ) {
                    if ( $arg->{$key} ) {
                        $new{ $key } = join( q{/}, $container_name, $arg->{$key} );
                    }
                }
                push @out, \%new;
            }
            else {
                push @out, { $self->fix_refs( $container_name, %{$arg} ) };
            }
        }
        elsif ( ref $arg eq 'ARRAY' ) {
            push @out, [ map { $self->fix_refs( $container_name, $_ ) } @{$arg} ];
        }
        else {
            push @out, $arg; # simple scalars
        }
    }
    return @out;
}

sub parse_args {
    my ( $self, $class, $args ) = @_;
    return if not $args;
    my @args;
    if ( ref $args eq 'ARRAY' ) {
        @args = $self->find_refs( @{$args} );
    }
    elsif ( ref $args eq 'HASH' ) {
        # Hash args could be a ref
        # Subcontainers cannot scan for refs in their configs
        if ( $class->isa( 'Beam::Wire' ) ) {
            my %args = %{$args};
            my $config = delete $args{config};
            # Relative subcontainer files should be from the current
            # container's directory
            if ( exists $args{file} && !file_name_is_absolute( $args{file} ) ) {
                $args{file} = catfile( $self->dir, $args{file} );
            }
            @args = $self->find_refs( %args );
            if ( $config ) {
                push @args, config => $config;
            }
        }
        else {
            my ( $maybe_ref ) = $self->find_refs( $args );
            if ( blessed $maybe_ref ) {
                @args = ( $maybe_ref );
            }
            else {
                @args   = ref $maybe_ref eq 'HASH' ? %$maybe_ref
                        : ref $maybe_ref eq 'ARRAY' ? @$maybe_ref
                        : ( $maybe_ref );
            }
        }
    }
    else {
        # Try anyway?
        @args = $args;
    }

    return @args;
}

sub create_service {
    my ( $self, $name, %service_info ) = @_;
    # Compose the parent ref into the copy, in case the parent changes
    %service_info = $self->merge_config( %service_info );
    # value and class/extends are mutually exclusive
    # must check after merge_config in case parent config has class/value
    if ( exists $service_info{value} && (
            exists $service_info{class} || exists $service_info{extends}
        )
    ) {
        Beam::Wire::Exception::InvalidConfig->throw(
            name => $name,
            file => $self->file,
        );
    }
    if ( $service_info{value} ) {
        return $service_info{value};
    }

    if ( $service_info{config} ) {
        my $conf_path = path( $service_info{config} );
        if ( $self->file ) {
            $conf_path = path( $self->file )->parent->child( $conf_path );
        }
        return $self->_load_config( "$conf_path" );
    }

    use_module( $service_info{class} );
    my $method = $service_info{method} || "new";
    my $service;
    if ( ref $method eq 'ARRAY' ) {
        for my $m ( @{$method} ) {
            my $method_name = $m->{method};
            my $return = $m->{return} || q{};
            delete $service_info{args};
            my @args = $self->parse_args( $service_info{class}, $m->{args} );
            my $invocant = $service || $service_info{class};
            my $output = $invocant->$method_name( @args );
            $service = !$service || $return eq 'chain' ? $output
                     : $service;
        }
    }
    else {
        my @args = $self->parse_args( @service_info{"class","args"} );
        $service = $service_info{class}->$method( @args );
    }

    if ( $service_info{on} ) {
        my %meta = $self->get_meta_names;
        for my $event ( keys %{ $service_info{on} } ) {
            my @listeners   = ref $service_info{on}{$event} eq 'ARRAY'
                            ? @{ $service_info{on}{$event} }
                            : $service_info{on}{$event}
                            ;

            for my $listener ( @listeners ) {
                # XXX: Make $class and $extends work here
                # XXX: Make $args prepend arguments to the listener
                # XXX: Make $args also resolve refs
                my $method = $listener->{ $meta{method} };
                my $listen_svc = $self->get( $listener->{ $meta{ref} } );
                $service->on( $event => sub { $listen_svc->$method( @_ ) } );
            }
        }
    }

    return $service;
}

sub merge_config {
    my ( $self, %service_info ) = @_;
    if ( $service_info{ extends } ) {
        my $base_config_ref = $self->get_config( $service_info{extends} );
        unless ( $base_config_ref ) { 
            Beam::Wire::Exception::NotFound->throw(
                name => $service_info{extends},
                file => $self->file,
            );
        }
        my %base_config = %{$base_config_ref};
        # Merge the args separately, to be a bit nicer about hashes of arguments
        my $args;
        if ( ref $service_info{args} eq 'HASH' && ref $base_config{args} eq 'HASH' ) {
            $args = { %{ delete $base_config{args} }, %{ delete $service_info{args} } };
        }
        %service_info = ( $self->merge_config( %base_config ), %service_info );
        if ( $args ) {
            $service_info{args} = $args;
        }
    }
    return %service_info;
}

sub find_refs {
    my ( $self, @args ) = @_;
    my @out;
    my %meta = $self->get_meta_names;
    for my $arg ( @args ) {
        if ( ref $arg eq 'HASH' ) {
            if ( $self->is_meta( $arg ) ) {
                if ( $arg->{ $meta{ ref } } ) {
                    push @out, $self->resolve_ref( $arg );
                }
                else { # Try to treat it as a service to create
                    my %service_info;
                    my $prefix = $self->meta_prefix;
                    for my $arg_key ( keys %{$arg} ) {
                        my $info_key = $arg_key;
                        $info_key =~ s/^\Q$prefix//;
                        $service_info{ $info_key } = $arg->{ $arg_key };
                    }
                    push @out, $self->create_service( '$anonymous', %service_info );
                }
            }
            else {
                push @out, { $self->find_refs( %{$arg} ) };
            }
        }
        elsif ( ref $arg eq 'ARRAY' ) {
            push @out, [ map { $self->find_refs( $_ ) } @{$arg} ];
        }
        else {
            push @out, $arg; # simple scalars
        }
    }
    return @out;
}

sub is_meta {
    my ( $self, $arg ) = @_;
    my $prefix = $self->meta_prefix;
    return !grep { !/^\Q$prefix/ } keys %{$arg};
}

sub get_meta_names {
    my ( $self ) = @_;
    my $prefix = $self->meta_prefix;
    my %meta = (
        ref     => "${prefix}ref",
        path    => "${prefix}path",
        method  => "${prefix}method",
        args    => "${prefix}args",
        class   => "${prefix}class",
        extends => "${prefix}extends",
    );
    return wantarray ? %meta : \%meta;
}

sub resolve_ref {
    my ( $self, $arg ) = @_;

    my %meta = $self->get_meta_names;

    my @ref;
    my $name = $arg->{ $meta{ref} };
    my $service = $self->get( $name );
    # resolve service ref w/path
    if ( my $path = $arg->{ $meta{path} } ) {
        # locate foreign service data
        my $conf = $self->get_config($name);
        @ref = dpath( $path )->match($service);
    }
    elsif ( my $method = $arg->{ $meta{method} } ) {
        my $args = $arg->{ $meta{args} };
        my @args = !$args                ? ()
                 : ref $args eq 'ARRAY'  ? @{ $args }
                 : $args;
        @ref = $service->$method( @args );
    }
    else {
        @ref = $service;
    }

    return @ref;
}


=method new

Create a new container.

=cut

sub BUILD {
    my ( $self ) = @_;

    if ( $self->file && !path( $self->file )->exists ) {
        my $file = $self->file;
        Beam::Wire::Exception::Constructor->throw(
            attr => 'file',
            error => qq{Container file '$file' does not exist},
        );
    }

    # Create all the eager services
    for my $key ( keys %{ $self->config } ) {
        my $config = $self->config->{$key};
        if ( $config->{lifecycle} && $config->{lifecycle} eq 'eager' ) {
            $self->get($key);
        }
    }
    return;
}

# Load a config file
sub _load_config {
    my ( $self, $path ) = @_;
    local $Config::Any::YAML::NO_YAML_XS_WARNING = 1;
    my $loader = Config::Any->load_files( {
        files  => [$path], use_ext => 1, flatten_to_hash => 1
    } );
   return "HASH" eq ref $loader ? (values(%{$loader}))[0] : {};
}

=head1 EXCEPTIONS

If there is an error internal to Beam::Wire, an exception will be thrown. If there is an
error with creating a service or calling a method, the exception thrown will be passed-
through unaltered.

=head2 Beam::Wire::Exception

The base exception class

=cut

package Beam::Wire::Exception;
use Moo;
with 'Throwable';
use Types::Standard qw( :all );
use overload q{""} => sub { $_[0]->error };

has error => (
    is => 'ro',
    isa => Str,
);

=head2 Beam::Wire::Exception::Constructor

An exception creating a Beam::Wire object

=cut

package Beam::Wire::Exception::Constructor;
use Moo;
use Types::Standard qw( :all );
extends 'Beam::Wire::Exception';

has attr => (
    is => 'ro',
    isa => Str,
    required => 1,
);

=head2 Beam::Wire::Exception::Service

An exception with service information inside

=cut

package Beam::Wire::Exception::Service;
use Moo;
use Types::Standard qw( :all );
extends 'Beam::Wire::Exception';

has name => (
    is          => 'ro',
    isa         => Str,
    required    => 1,
);

has file => (
    is          => 'ro',
    isa         => Maybe[Str],
);

=head2 Beam::Wire::Exception::NotFound

The requested service or configuration was not found.

=cut

package Beam::Wire::Exception::NotFound;
use Moo;
extends 'Beam::Wire::Exception::Service';

=head2 Beam::Wire::Exception::InvalidConfig

The configuration is invalid:

=over 4

=item *

Both "value" and "class" or "extends" are defined. These are mutually-exclusive.

=back

=cut

package Beam::Wire::Exception::InvalidConfig;
use Moo;
extends 'Beam::Wire::Exception::Service';

1;
