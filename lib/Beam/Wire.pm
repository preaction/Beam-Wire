package Beam::Wire;
our $VERSION = '1.030';
# ABSTRACT: Lightweight Dependency Injection Container

=head1 SYNOPSIS

    # wire.yml
    captain:
        class: Person
        args:
            name: Malcolm Reynolds
            rank: Captain
    first_officer:
        $class: Person
        name: Zoë Alleyne Washburne
        rank: Commander

    # script.pl
    use Beam::Wire;
    my $wire = Beam::Wire->new( file => 'wire.yml' );
    my $captain = $wire->get( 'captain' );
    print $captain->name; # "Malcolm Reynolds"

=head1 DESCRIPTION

Beam::Wire is a configuration module and a dependency injection
container. In addition to complex data structures, Beam::Wire configures
and creates plain old Perl objects.

A dependency injection (DI) container creates an inversion of control:
Instead of manually creating all the dependent objects (also called
"services") before creating the main object that we actually want, a DI
container handles that for us: We describe the relationships between
objects, and the objects get built as needed.

Dependency injection is sometimes called the opposite of garbage
collection. Rather than ensure objects are destroyed in the right order,
dependency injection makes sure objects are created in the right order.

Using Beam::Wire in your application brings great flexibility,
allowing users to easily add their own code to customize how your
project behaves.

For an L<introduction to the Beam::Wire service configuration format,
see Beam::Wire::Help::Config|Beam::Wire::Help::Config>.

=cut

use strict;
use warnings;

use constant DEBUG => $ENV{BEAM_WIRE_DEBUG};

use Scalar::Util qw( blessed );
use Moo;
use Config::Any;
use Module::Runtime qw( use_module );
use Path::Tiny qw( path );
use Types::Standard qw( :all );
use if DEBUG, 'Data::Dumper' => qw( Dumper );
use Beam::Wire::Event::ConfigService;
use Beam::Wire::Event::BuildService;
with 'Beam::Emitter';

=attr file

The path of the file where services are configured (typically a YAML
file). The file's contents should be a single hashref. The keys are
service names, and the values are L<service
configurations|Beam::Wire::Help::Config>.

=cut

has file => (
    is      => 'ro',
    isa     => InstanceOf['Path::Tiny'],
    coerce => sub {
        if ( !blessed $_[0] || !$_[0]->isa('Path::Tiny') ) {
            return path( $_[0] );
        }
        return $_[0];
    },
);

=attr dir

The directory path or paths to use when searching for inner container files.
Defaults to using the directory which contains the file specified by the
L<file attribute|/file> followed by the C<BEAM_PATH> environment variable
(separated by colons C<:>).

=cut

has dir => (
    is      => 'ro',
    isa     => ArrayRef[InstanceOf['Path::Tiny']],
    lazy    => 1,
    default => sub {
      my $dir = [
        ($_[0]->file ? ($_[0]->file->parent) : ()),
        ($ENV{BEAM_PATH} ? (map { path($_) } grep !!$_, split /:/, $ENV{BEAM_PATH}) : ()),
      ];
      ; print 'Using default paths ', Dumper $dir if DEBUG;
      return $dir;
    },
    coerce => sub {
        if ( !ref $_[0] ) {
            return [path( $_[0] )];
        }
        if ( ref $_[0] eq 'ARRAY' ) {
          return [map { blessed( $_ ) && $_->isa('Path::Tiny') ? $_ : path($_) } @{$_[0]}];
        }
        return $_[0];
    },
);

=attr config

The raw configuration data. By default, this data is loaded by
L<Config::Any|Config::Any> using the file specified by the L<file attribute|/file>.

See L<Beam::Wire::Help::Config for details on what the configuration
data structure looks like|Beam::Wire::Help::Config>.

If you don't want to load a file, you can specify this attribute in the
Beam::Wire constructor.

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

A hashref of cached services built from the L<configuration|/config>. If
you want to inject a pre-built object for other services to depend on,
add it here.

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

The default value is C<$>. The empty string is allowed.

=cut

has meta_prefix => (
    is      => 'ro',
    isa     => Str,
    default => sub { q{$} },
);

=method get

    my $service = $wire->get( $name );
    my $service = $wire->get( $name, %overrides )

The get method resolves and returns the service named C<$name>, creating
it, if necessary, with L<the create_service method|/create_service>.

C<%overrides> is an optional list of name-value pairs. If specified,
get() will create an new, anonymous service that extends the named
service with the given config overrides. For example:

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

If C<$name> contains a slash (C</>) character (e.g. C<foo/bar>), the left
side (C<foo>) will be used as the name of an inner container, and the
right side (C<bar>) is a service inside that container. For example,
these two lines are equivalent:

    $bar = $wire->get( 'foo/bar' );
    $bar = $wire->get( 'foo' )->get( 'bar' );

Inner containers can be nested as deeply as desired (C<foo/bar/baz/fuzz>).

=cut

sub get {
    my ( $self, $name, %override ) = @_;

    ; print STDERR "Get service: $name\n" if DEBUG;

    if ( $name =~ q{/} ) {
        my ( $container_name, $service_name ) = split m{/}, $name, 2;
        my $container = $self->get( $container_name );
        my $unsub_config = $container->on( configure_service => sub {
            my ( $event ) = @_;
            $self->emit( configure_service =>
                class => 'Beam::Wire::Event::ConfigService',
                service_name => join( '/', $container_name, $event->service_name ),
                config => $event->config,
            );
        } );
        my $unsub_build = $container->on( build_service => sub {
            my ( $event ) = @_;
            $self->emit( build_service =>
                class => 'Beam::Wire::Event::BuildService',
                service_name => join( '/', $container_name, $event->service_name ),
                service => $event->service,
            );
        } );
        my $service = $container->get( $service_name, %override );
        $unsub_config->();
        $unsub_build->();
        return $service;
    }

    if ( keys %override ) {
        return $self->create_service(
            "\$anonymous extends $name",
            %override,
            extends => $name,
        );
    }

    my $service = $self->services->{$name};
    if ( !$service ) {
        ; printf STDERR 'Service "%s" does not exist. Creating.' . "\n", $name if DEBUG;

        my $config_ref = $self->get_config($name);
        unless ( $config_ref ) {
            Beam::Wire::Exception::NotFound->throw(
                name => $name,
                file => $self->file,
            );
        }

        ; print STDERR "Got service config: " . Dumper( $config_ref ) if DEBUG;

        if ( ref $config_ref eq 'HASH' && $self->is_meta( $config_ref, 1 ) ) {
            my %config  = %{ $self->normalize_config( $config_ref ) };
            $service = $self->create_service( $name, %config );
            if ( !$config{lifecycle} || lc $config{lifecycle} ne 'factory' ) {
                $self->services->{$name} = $service;
            }
        }
        else {
            $self->services->{$name} = $service = $self->find_refs( $name, $config_ref );
        }
    }

    ; print STDERR "Returning service: " . Dumper( $service ) if DEBUG;

    return $service;
}

=method set

    $wire->set( $name => $service );

The set method configures and stores the specified C<$service> with the
specified C<$name>. Use this to add or replace built services.

Like L<the get() method, above|/get>, C<$name> can contain a slash (C</>)
character to traverse through nested containers.

=cut

## no critic ( ProhibitAmbiguousNames )
# This was named set() before I started using Perl::Critic, and will
# continue to be named set() now that I no longer use Perl::Critic
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

    my $conf = $wire->get_config( $name );

Get the config with the given C<$name>. Like L<the get() method,
above|/get>, C<$name> can contain slash (C</>) characters to traverse
through nested containers.

=cut

sub get_config {
    my ( $self, $name ) = @_;
    if ( $name =~ q{/} ) {
        my ( $container_name, $service ) = split m{/}, $name, 2;
        my %inner_config = %{ $self->get( $container_name )->get_config( $service ) };
        # Fix relative references to prefix the container name
        my ( $fixed_config ) = $self->fix_refs( $container_name, \%inner_config );
        return $fixed_config;
    }
    return $self->config->{$name};
}

=method normalize_config

    my $out_conf = $self->normalize_config( $in_conf );

Normalize the given C<$in_conf> into to hash that L<the create_service
method|/create_service> expects. This method allows a service to be
defined with prefixed meta-names (C<$class> instead of C<class>) and
the arguments specified without prefixes.

For example, these two services are identical.

    foo:
        class: Foo
        args:
            fizz: buzz

    foo:
        $class: Foo
        fizz: buzz

The C<$in_conf> must be a hash, and must already pass L<an is_meta
check|/is_meta>.

=cut

sub normalize_config {
    my ( $self, $conf ) = @_;

    ; print STDERR "In conf: " . Dumper( $conf ) if DEBUG;

    my %meta = reverse $self->get_meta_names;

    # Confs without prefixed keys can be used as-is
    return $conf if !grep { $meta{ $_ } } keys %$conf;

    my %out_conf;
    for my $key ( keys %$conf ) {
        if ( $meta{ $key } ) {
            $out_conf{ $meta{ $key } } = $conf->{ $key };
        }
        else {
            $out_conf{ args }{ $key } = $conf->{ $key };
        }
    }

    ; print STDERR "Out conf: " . Dumper( \%out_conf ) if DEBUG;

    return \%out_conf;
}

=method create_service

    my $service = $wire->create_service( $name, %config );

Create the service with the given C<$name> and C<%config>. Config can
contain the following keys:

=over 4

=item class

The class name of an object to create. Can be combined with C<method>,
and C<args>. An object of any class can be created with Beam::Wire.

=item args

The arguments to the constructor method. Used with C<class> and
C<method>. Can be a simple value, or a reference to an array or
hash which will be dereferenced and passed in to the constructor
as a list.

If the C<class> consumes the L<Beam::Service role|Beam::Service>,
the service's C<name> and C<container> will be added to the C<args>.

=item method

The method to call to create the object. Only used with C<class>.
Defaults to C<"new">.

This can also be an array of hashes which describe a list of methods
that will be called on the object. The first method should create the
object, and each subsequent method can be used to modify the object. The
hashes should contain a C<method> key, which is a string containing the
method to call, and optionally C<args> and C<return> keys. The C<args>
key works like the top-level C<args> key, above. The optional C<return>
key can have the special value C<"chain">, which will use the return
value from the method as the value for the service (L<The tutorial shows
examples of this|Beam::Wire::Help::Config/Multiple Constructor
Methods>).

If an array is used, the top-level C<args> key is not used.

=item value

The value of this service. Can be a simple value, or a reference to an
array or hash. This value will be simply returned by this method, and is
mostly useful when using container files.

C<value> can not be used with C<class> or C<extends>.

=item ref

A reference to another service.  This may be paired with C<call> or C<path>.

=item config

The path to a configuration file, relative to L<the dir attribute|/dir>.
The file will be read with L<Config::Any>, and the resulting data
structure returned. If the config file does not exist, will return the
data in the C<$default> attribute. If the C<$default> attribute does not
exist, will return C<undef>.

C<config> can not be used with C<class> or C<extends>.

=item env

Get the value from an environment variable. If the environment variable does not exist, will return the
data in the C<$default> attribute. If the C<$default> attribute does not exist, will return C<undef>.

C<env> can not be used with C<class> or C<extends>.

=item extends

The name of a service to extend. The named service's configuration will
be merged with this configuration (via L<the merge_config
method|/merge_config>).

This can be used in place of the C<class> key if the extended configuration
contains a class.

=item with

Compose a role into the object's class before creating the object. This
can be a single string, or an array reference of strings which are roles
to combine.

This uses L<Moo::Role|Moo::Role> and L<the create_class_with_roles
method|Role::Tiny/create_class_with_roles>, which should work with any
class (as it uses L<the Role::Tiny module|Role::Tiny> under the hood).

This can be used with the C<class> key.

=item on

Attach an event handler to a L<Beam::Emitter subclass|Beam::Emitter>. This
is an array of hashes of event names and handlers. A handler is made from
a service reference (C<$ref> or an anonymous service), and a subroutine to
call on that service (C<$sub>).

For example:

    emitter:
        class: My::Emitter
        on:
            - my_event:
                $ref: my_handler
                $sub: on_my_event

This can be used with the C<class> key.

=back

This method uses L<the parse_args method|/parse_args> to parse the C<args> key,
L<resolving references|resolve_ref> as needed.

=cut

sub create_service {
    my ( $self, $name, %service_info ) = @_;

    ; print STDERR "Creating service: " . Dumper( \%service_info ) if DEBUG;

    # Compose the parent ref into the copy, in case the parent changes
    %service_info = $self->merge_config( %service_info );

    # value | ref | config and class/extends are mutually exclusive
    # must check after merge_config in case parent config has class/value

    my @classy = grep  { exists $service_info{$_} } qw( class extends );
    my @other =  grep  { exists $service_info{$_} } qw( value ref config env );

    if ( @other > 1 ) {
        Beam::Wire::Exception::InvalidConfig->throw(
            name => $name,
            file => $self->file,
            error => 'use only one of "value", "ref", "env", or "config"',
        );
    }

    if ( @classy && @other  ) {  # @other == 1
        Beam::Wire::Exception::InvalidConfig->throw(
            name => $name,
            file => $self->file,
            error => qq{"$other[0]" cannot be used with "class" or "extends"},
        );
    }

    if ( exists $service_info{value} ) {
        return $service_info{value};
    }

    if ( exists $service_info{env} ) {
        return exists $ENV{$service_info{env}} ? $ENV{$service_info{env}} : ($service_info{default} // undef);
    }

    if ( exists $service_info{ref} ){
        # at this point the service info is normalized, so none of the
        # meta keys have a prefix.  this will cause resolve_ref some angst,
        # so de-normalize them
        my %meta = $self->get_meta_names;
        my %de_normalized = map { $meta{$_} // $_ => $service_info{$_} } keys %service_info;
        return ( $self->resolve_ref( $name, \%de_normalized ) )[0];
    }

    if ( $service_info{config} ) {
        my $conf_path = path( $service_info{config} );
        if ( !$conf_path->is_absolute ) {
            $conf_path = $self->_resolve_relative_path($conf_path);
        }
        if ($service_info{default} && (!$conf_path || !$conf_path->is_file)) {
            return $service_info{default};
        }
        return $self->_load_config( "$conf_path" );
    }

    if ( !$service_info{class} ) {
        Beam::Wire::Exception::InvalidConfig->throw(
            name => $name,
            file => $self->file,
            error => 'Service configuration incomplete. Missing one of "class", "value", "config", "ref"',
        );
    }

    $self->emit( configure_service =>
        class => 'Beam::Wire::Event::ConfigService',
        service_name => $name,
        config => \%service_info,
    );

    use_module( $service_info{class} );

    if ( my $with = $service_info{with} ) {
        my @roles = ref $with ? @{ $with } : ( $with );
        my $class = Moo::Role->create_class_with_roles( $service_info{class}, @roles );
        $service_info{class} = $class;
    }

    my $method = $service_info{method} || "new";
    my $service;
    if ( ref $method eq 'ARRAY' ) {
        for my $m ( @{$method} ) {
            my $method_name = $m->{method};
            my $return = $m->{return} || q{};
            delete $service_info{args};
            my @args = $self->parse_args( $name, $service_info{class}, $m->{args} );
            my $invocant = defined $service ? $service : $service_info{class};
            my $output = $invocant->$method_name( @args );
            $service = !defined $service || $return eq 'chain' ? $output
                     : $service;
        }
    }
    else {
        my @args = $self->parse_args( $name, @service_info{"class","args","default"} );
        if ( $service_info{class}->can( 'DOES' ) && $service_info{class}->DOES( 'Beam::Service' ) ) {
            push @args, name => $name, container => $self;
        }
        $service = $service_info{class}->$method( @args );
    }

    if ( $service_info{on} ) {
        my %meta = $self->get_meta_names;
        my @listeners;

        if ( ref $service_info{on} eq 'ARRAY' ) {
            @listeners = map { [ %$_ ] } @{ $service_info{on} };
        }
        elsif ( ref $service_info{on} eq 'HASH' ) {
            for my $event ( keys %{ $service_info{on} } ) {
                if ( ref $service_info{on}{$event} eq 'ARRAY' ) {
                    push @listeners,
                        map {; [ $event => $_ ] }
                        @{ $service_info{on}{$event} };
                }
                else {
                    push @listeners, [ $event => $service_info{on}{$event} ];
                }
            }
        }

        for my $listener ( @listeners ) {
            my ( $event, $conf ) = @$listener;
            if ( $conf->{ $meta{method} } && !$conf->{ $meta{sub} } ) {
                _deprecated( 'warning: (deprecated) "$method" in event handlers is now "$sub" in service "' . $name . '"' );
            }
            my $sub_name = delete $conf->{ $meta{sub} } || delete $conf->{ $meta{method} };
            my ( $listen_svc ) = $self->find_refs( $name, $conf );
            $service->on( $event => sub { $listen_svc->$sub_name( @_ ) } );
        }
    }

    $self->emit( build_service =>
        class => 'Beam::Wire::Event::BuildService',
        service_name => $name,
        service => $service,
    );

    return $service;
}

=method merge_config

    my %merged = $wire->merge_config( %config );

If C<%config> contains an C<extends> key, merge the extended config together
with this one, returning the merged service configuration. This works recursively,
so a service can extend a service that extends another service just fine.

When merging, hashes are combined, with the child configuration taking
precedence. The C<args> key is handled specially to allow a hash of
args to be merged. A single element array of args is merged too, if the
element is a hash.

The configuration returned is a safe copy and can be modified without
effecting the original config.

=cut

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
        my %base_config = %{ $self->normalize_config( $base_config_ref ) };
        # Merge the args separately, to be a bit nicer about hashes of arguments
        my $args;
        if ( ref $service_info{args} eq 'HASH' && ref $base_config{args} eq 'HASH' ) {
            $args = { %{ delete $base_config{args} }, %{ delete $service_info{args} } };
        } elsif ( ref $service_info{args} eq 'ARRAY' && @{ $service_info{args} } == 1 && ref $service_info{args}->[0] eq 'HASH' &&
                  ref $base_config{args}  eq 'ARRAY' && @{ $base_config{args} }  == 1 && ref $base_config{args}->[0]  eq 'HASH' ) {
            $args = [ { %{ delete($base_config{args})->[0] }, %{ delete($service_info{args})->[0] } } ];
        }
        %service_info = ( $self->merge_config( %base_config ), %service_info );
        if ( $args ) {
            $service_info{args} = $args;
        }
    }
    return %service_info;
}

=method parse_args

    my @args = $wire->parse_args( $for_name, $class, $args );

Parse the arguments (C<$args>) for the given service (C<$for_name>) with
the given class (C<$class>).

C<$args> can be an array reference, a hash reference, or a simple
scalar. The arguments will be searched for references using L<the
find_refs method|/find_refs>, and then a list of arguments will be
returned, ready to pass to the object's constructor.

Nested containers are handled specially by this method:

=over

=item * Inner references are not resolved by the parent container.
This ensures that references are always relative to the container they're in.

=item * If a file is specified but cannot be found, a C<default> can be provided
as a fallback.

=back

=cut

# NOTE: Fallback only works on nested Beam::Wire containers right now.
# I don't know what one could use to detect one should fall back for
# any other kind of service...
sub parse_args {
    my ( $self, $for, $class, $args, $fallback ) = @_;
    return if not $args;
    my @args;
    if ( ref $args eq 'ARRAY' ) {
        @args = $self->find_refs( $for, @{$args} );
    }
    elsif ( ref $args eq 'HASH' ) {
        # Hash args could be a ref
        # Subcontainers cannot scan for refs in their configs
        if ( $class->isa( 'Beam::Wire' ) ) {
            my %args = %{$args};
            my $config = delete $args{config};
            # Subcontainer files should inherit the lookup paths of the
            # current container, unless overridden.
            $args{dir} //= $self->dir;
            # Relative subcontainer files should be looked up from the list of dirs.
            if ( exists $args{file} && !path( $args{file} )->is_absolute ) {
                $args{file} = $self->_resolve_relative_path($args{file}, $args{dir});
            }
            # If the file doesn't exist, try to fall back to a default
            if ( exists $args{file} && !($args{file} && path( $args{file} )->is_file) && $fallback ) {
                delete $args{file};
                %args = (%args, %$fallback);
            }
            @args = $self->find_refs( $for, %args );
            if ( $config ) {
                push @args, config => $config;
            }
        }
        else {
            my ( $maybe_ref ) = $self->find_refs( $for, $args );
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

=method find_refs

    my @resolved = $wire->find_refs( $for_name, @args );

Go through the C<@args> and recursively resolve any references and
services found inside, returning the resolved result. References are
identified with L<the is_meta method|/is_meta>.

If a reference contains a C<$ref> key, it will be resolved by L<the
resolve_ref method|/resolve_ref>. Otherwise, the reference will be
treated as an anonymous service, and passed directly to L<the
create_service method|/create_service>.

This is used when L<creating a service|create_service> to ensure all
dependencies are created first.

=cut

sub find_refs {
    my ( $self, $for, @args ) = @_;

    ; printf STDERR qq{Searching for refs for "%s": %s}, $for, Dumper( \@args ) if DEBUG;

    my @out;
    my %meta = $self->get_meta_names;
    for my $arg ( @args ) {
        if ( ref $arg eq 'HASH' ) {
            if ( $self->is_meta( $arg ) ) {
                if ( $arg->{ $meta{ ref } } ) {
                    push @out, $self->resolve_ref( $for, $arg );
                }
                else { # Try to treat it as a service to create
                    ; print STDERR "Creating anonymous service: " . Dumper( $arg ) if DEBUG;

                    my %service_info = %{ $self->normalize_config( $arg ) };
                    push @out, $self->create_service( '$anonymous', %service_info );
                }
            }
            else {
                push @out, { $self->find_refs( $for, %{$arg} ) };
            }
        }
        elsif ( ref $arg eq 'ARRAY' ) {
            push @out, [ map { $self->find_refs( $for, $_ ) } @{$arg} ];
        }
        else {
            push @out, $arg; # simple scalars
        }
    }

    # In case we only pass in one argument and want one return value
    return wantarray ? @out : $out[-1];
}

=method is_meta

    my $is_meta = $wire->is_meta( $ref_hash, $root );

Returns true if the given hash reference describes some kind of
Beam::Wire service. This is used to identify service configuration
hashes inside of larger data structures.

A service hash reference must contain at least one key, and must either
contain a L<prefixed|/meta_prefix> key that could create or reference an
object (one of C<class>, C<extends>, C<config>, C<value>, C<env>, or C<ref>) or,
if the C<$root> flag exists, be made completely of unprefixed meta keys
(as returned by L<the get_meta_names method|/get_meta_names>).

The C<$root> flag is used by L<the get method|/get> to allow unprefixed
meta keys in the top-level hash values.

=cut

sub is_meta {
    my ( $self, $arg, $root ) = @_;

    # Only a hashref can be meta
    return unless ref $arg eq 'HASH';

    my @keys = keys %$arg;
    return unless @keys;

    my %meta = $self->get_meta_names;

    # A regular service does not need the prefix, but must consist
    # only of meta keys
    return 1 if $root && scalar @keys eq grep { $meta{ $_ } } @keys;

    # A meta service contains at least one of these keys, as these are
    # the keys that can create a service. All other keys are
    # modifiers
    return 1
        if grep { exists $arg->{ $_ } }
            map { $meta{ $_ } }
            qw( ref class extends config value env );

    # Must not be meta
    return;
}

=method get_meta_names

    my %meta_keys = $wire->get_meta_names;

Get all the possible service keys with the L<meta prefix|/meta_prefix> already
attached.

=cut

sub get_meta_names {
    my ( $self ) = @_;
    my $prefix = $self->meta_prefix;
    my %meta = (
        ref         => "${prefix}ref",
        path        => "${prefix}path",
        method      => "${prefix}method",
        args        => "${prefix}args",
        class       => "${prefix}class",
        extends     => "${prefix}extends",
        sub         => "${prefix}sub",
        call        => "${prefix}call",
        lifecycle   => "${prefix}lifecycle",
        on          => "${prefix}on",
        with        => "${prefix}with",
        value       => "${prefix}value",
        config      => "${prefix}config",
        env         => "${prefix}env",
        default     => "${prefix}default",
    );
    return wantarray ? %meta : \%meta;
}

=method resolve_ref

    my @value = $wire->resolve_ref( $for_name, $ref_hash );

Resolves the given dependency from the configuration hash (C<$ref_hash>)
for the named service (C<$for_name>). Reference hashes contain the
following keys:

=over 4

=item $ref

The name of a service in the container. Required.

=item $path

A data path to pick some data out of the reference. Useful with C<value>
and C<config> services.

    # container.yml
    bounties:
        value:
            malcolm: 50000
            zoe: 35000
            simon: 100000

    captain:
        class: Person
        args:
            name: Malcolm Reynolds
            bounty:
                $ref: bounties
                $path: /malcolm

=item $call

Call a method on the referenced object and use the resulting value. This
may be a string, which will be the method name to call, or a hash with
C<$method> and C<$args>, which are the method name to call and the
arguments to that method, respectively.

    captain:
        class: Person
        args:
            name: Malcolm Reynolds
            location:
                $ref: beacon
                $call: get_location
            bounty:
                $ref: news
                $call:
                    $method: get_bounty
                    $args:
                        name: mreynolds

=back

=cut

sub resolve_ref {
    my ( $self, $for, $arg ) = @_;

    my %meta = $self->get_meta_names;

    my @ref;
    my $name = $arg->{ $meta{ref} };
    my $service = $self->get( $name );
    # resolve service ref w/path
    if ( my $path = $arg->{ $meta{path} } ) {
        # locate foreign service data
        use_module( 'Data::DPath' )->import('dpath');
        @ref = dpath( $path )->match($service);
    }
    elsif ( my $call = $arg->{ $meta{call} } ) {
        my ( $method, @args );

        if ( ref $call eq 'HASH' ) {
            $method = $call->{ $meta{method} };
            my $args = $call->{ $meta{args} };
            @args = !$args ? ()
                  : ref $args eq 'ARRAY'  ? @{ $args }
                  : $args;
        }
        else {
            $method = $call;
        }

        @ref = $service->$method( @args );
    }
    elsif ( my $method = $arg->{ $meta{method} } ) {
        _deprecated( 'warning: (deprecated) Using "$method" to get a value in a dependency is now "$call" in service "' . $for . '"' );
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

=method fix_refs

    my @fixed = $wire->fix_refs( $for_container_name, @args );

Similar to L<the find_refs method|/find_refs>. This method searches
through the C<@args> and recursively fixes any reference paths to be
absolute. References are identified with L<the is_meta
method|/is_meta>.

This is used by L<the get_config method|/get_config> to ensure that the
configuration can be passed directly in to L<the create_service
method|create_service>.

=cut

sub fix_refs {
    my ( $self, $container_name, @args ) = @_;
    my @out;
    my %meta = $self->get_meta_names;
    for my $arg ( @args ) {
        if ( ref $arg eq 'HASH' ) {
            if ( $self->is_meta( $arg, 1 ) ) {
                #; print STDERR 'Fixing refs for arg: ' . Dumper( $arg );
                my %new = %$arg;
                for my $key ( keys %new ) {
                    if ( $key =~ /(?:ref|extends)$/ ) {
                        $new{ $key } = join( q{/}, $container_name, $new{$key} );
                    }
                    else {
                        ( $new{ $key } ) = $self->fix_refs( $container_name, $new{ $key } );
                    }
                }
                #; print STDERR 'Fixed refs for arg: ' . Dumper( \%new );
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


=method new

    my $wire = Beam::Wire->new( %attributes );

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
    my %meta = $self->get_meta_names;
    for my $key ( keys %{ $self->config } ) {
        my $config = $self->config->{$key};
        if ( ref $config eq 'HASH' ) {
            my $lifecycle = $config->{lifecycle} || $config->{ $meta{lifecycle} };
            if ( $lifecycle && $lifecycle eq 'eager' ) {
                $self->get($key);
            }
        }
    }
    return;
}

my %deprecated_warnings;
sub _deprecated {
    my ( $warning ) = @_;
    return if $deprecated_warnings{ $warning };
    warn $deprecated_warnings{ $warning } = $warning . "\n";
}

# Load a config file
sub _load_config {
    my ( $self, $path ) = @_;
    local $Config::Any::YAML::NO_YAML_XS_WARNING = 1;

    my $loader;
    eval {
        $loader = Config::Any->load_files( {
            files  => [$path], use_ext => 1, flatten_to_hash => 1
        } );
    };
    if ( $@ ) {
        Beam::Wire::Exception::Config->throw(
            file => $self->file,
            config_error => $@,
        );
    }

   return "HASH" eq ref $loader ? (values(%{$loader}))[0] : {};
}

sub _resolve_relative_path {
    my ( $self, $file, $dirs ) = @_;
    $dirs //= $self->dir;
    ; printf STDERR qq{Searching for path '%s' in %s}, $file, Dumper( $dirs ) if DEBUG;
    for my $dir ( @{ $dirs } ) {
        $dir = !(blessed $dir && $dir->isa('Path::Tiny')) ? path($dir) : $dir;
        if ($dir->child($file)->exists) {
            return $dir->child( $file );
        }
    }
    # Allow the file to fall through so we get an error message with
    # the relative filename that we tried looking up.
    return $file;
}

# Check config file for known issues and report
# Optionally attempt to get all configured items for complete test
# Intended for use with beam-wire script
sub validate {
    my $error_count = 0;
    my @valid_dependency_nodes = qw( class method args extends lifecycle on config );
    my ( $self, $instantiate, $show_all_errors ) = @_;

    while ( my ( $name, $v ) = each %{ $self->{config} } ) {

        if ($instantiate) {
            if ($show_all_errors) {
                eval {
                    $self->get($name);
                };
                print $@ if $@;
            }
            else {
                $self->get($name);
            }
            next;
        };

        my %config = %{ $self->get_config($name) };
        %config = $self->merge_config(%config);

        my @classy = grep  { exists $config{$_} } qw( class extends );
        my @other =  grep  { exists $config{$_} } qw( value ref config );

        if ( @other > 1 ) {
            $error_count++;
            my $error = 'use only one of "value", "ref", or "config"';

            if ($show_all_errors) {
                print qq(Invalid config for service '$name': $error\n);
                next;
            }

            Beam::Wire::Exception::InvalidConfig->throw(
                name => $name,
                file => $self->file,
                error => $error,
            );
        }

        if ( @classy && @other  ) {  # @other == 1
            $error_count++;
            my $error = qq{"$other[0]" cannot be used with "class" or "extends"};

            if ($show_all_errors) {
                print qq(Invalid config for service '$name': $error\n);
                next;
            }

            Beam::Wire::Exception::InvalidConfig->throw(
                name => $name,
                file => $self->file,
                error => $error,
            );
        }

        if ( exists $config{value} && ( exists $config{class} || exists $config{extends})) {
            $error_count++;
            if ($show_all_errors) {
                print qq(Invalid config for service '$name': "value" cannot be used with "class" or "extends"\n);
                next;
            }

            Beam::Wire::Exception::InvalidConfig->throw(
                name => $name,
                file => $self->file,
                error => '"value" cannot be used with "class" or "extends"',
            );
        }

        if ( $config{config} ) {
            my $conf_path = path( $config{config} );
            if ( $self->file ) {
                $conf_path = path( $self->file )->parent->child($conf_path);
            }
            %config = %{ $self->_load_config("$conf_path") };
        }

        unless ( $config{value} || $config{class} || $config{extends} || $config{ref} ) {
            next;
        }

        if ($config{class}) {
            eval "require " . $config{class} if $config{class};
        }
        #TODO: check method chain & serial
    }
    return $error_count;
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

=head2 Beam::Wire::Exception::Config

An exception loading the configuration file.

=cut

package Beam::Wire::Exception::Config;
use Moo;
use Types::Standard qw( :all );
extends 'Beam::Wire::Exception';

has file => (
    is          => 'ro',
    isa         => Maybe[InstanceOf['Path::Tiny']],
);

has config_error => (
    is => 'ro',
    isa => Str,
    required => 1,
);

has '+error' => (
    lazy => 1,
    default => sub {
        my ( $self ) = @_;
        return sprintf 'Could not load container file "%s": Error from config parser: %s',
            $self->file,
            $self->config_error;
    },
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
    isa         => Maybe[InstanceOf['Path::Tiny']],
);

=head2 Beam::Wire::Exception::NotFound

The requested service or configuration was not found.

=cut

package Beam::Wire::Exception::NotFound;
use Moo;
extends 'Beam::Wire::Exception::Service';

has '+error' => (
    lazy => 1,
    default => sub {
        my ( $self ) = @_;
        my $name = $self->name;
        my $file = $self->file;
        return "Service '$name' not found" . ( $file ? " in file '$file'" : '' );
    },
);

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
use overload q{""} => sub {
    my ( $self ) = @_;
    my $file = $self->file;

    sprintf "Invalid config for service '%s': %s%s",
        $self->name,
        $self->error,
        ( $file ? " in file '$file'" : "" ),
        ;
};

=head1 EVENTS

The container emits the following events.

=head2 configure_service

This event is emitted when a new service is configured, but before it is
instantiated or any classes loaded. This allows altering of the
configuration before the service is built. Already-built services will
not fire this event.

Event handlers get a L<Beam::Wire::Event::ConfigService> object as their
only argument.

This event will bubble up from child containers.

=head2 build_service

This event is emitted when a new service is built. Cached services will
not fire this event.

Event handlers get a L<Beam::Wire::Event::BuildService> object as their
only argument.

This event will bubble up from child containers.

=cut

1;
__END__

=head1 ENVIRONMENT VARIABLES

=over 4

=item BEAM_PATH

A colon-separated list of directories to look up inner container files. Use this
to allow adding containers for (e.g.) Docker/Kubernetes deployments.

=item BEAM_WIRE_DEBUG

If set, print a bunch of internal debugging information to STDERR.

=back

