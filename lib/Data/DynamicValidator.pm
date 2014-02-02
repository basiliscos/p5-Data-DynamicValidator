package Data::DynamicValidator;
#ABSTRACT: JPointer-like and Perl union for flexible perl data structures validation

use strict;
use warnings;

use Carp;
use Devel::LexAlias qw(lexalias);
use PadWalker qw(peek_sub);
use Scalar::Util qw/looks_like_number/;
use Storable qw(dclone);

use aliased qw/Data::DynamicValidator::Error/;
use aliased qw/Data::DynamicValidator::Filter/;
use aliased qw/Data::DynamicValidator::Label/;
use aliased qw/Data::DynamicValidator::Path/;

use overload
    fallback => 1,
    '&{}' => sub {
        my $self = shift;
        return sub { $self->validate(@_) }
    };

use parent qw/Exporter/;
our @EXPORT_OK = qw/validator/;

use constant DEBUG => $ENV{DATA_DYNAMICVALIDATOR_DEBUG} || 0;

=head1 SYNOPSIS

 my $my_complex_config = {
    features => [
        "a/f",
        "application/feature1",
        "application/feature2",
    ],
    service_points => {
        localhost => {
            "a/f" => { job_slots => 3, },
            "application/feature1" => { job_slots => 5 },
            "application/feature2" => { job_slots => 5 },
        },
        "127.0.0.1" => {
            "application/feature2" => { job_slots => 5 },
        },
    },
    mojolicious => {
    	hypnotoad => {
            pid_file => '/tmp/hypnotoad-ng.pid',
            listen  => [ 'http://localhost:3000' ],
        },
    },
 };

 use Data::DynamicValidator qw/validator/;

 my $errors = validator($cfg)->(
   on      => '/features/*',
   should  => sub { @_ > 0 },
   because => "at least one feature should be defined",
   each    => sub {
     my $f = $_->();
     shift->(
       on      => "/service_points/*/`$f`/job_slots",
       should  => sub { defined($_[0]) && $_[0] > 0 },
       because => "at least 1 service point should be defined for feature '$f'",
     )
   }
 )->(
   on      => '/service_points/sp:*',
   should  => sub { @_ > 0 },
   because => "at least one service point should be defined",
   each    => sub {
     my $sp;
     shift->report_error("SP '$sp' isn't resolvable")
       unless gethost($sp);
   }
 )->(
  on      => '/service_points/sp:*/f:*',
  should  => sub { @_ > 0 },
  because => "at least one feature under service point should be defined",
  each    => sub {
    my ($sp, $f);
    shift->(
      on      => "/features/`*[value eq '$f']`",
      should  => sub { 1 },
      because => "Feature '$f' of service point '$sp' should be decrlared in top-level features list",
    )
  },
 )->(
   on      => '/mojolicious/hypnotoad/pid_file',
   should  => sub { @_ == 1 },
   because => "hypnotoad pid_file should be defined",
 )->(
   on      => '/mojolicious/hypnotoad/listen/*',
   should  => sub { @_ > 0 },
   because => "hypnotoad listening interfaces defined",
 )->errors;

 print "all OK\n"
  unless(@$errors);

=cut

=func validator

The enter point for DynamicValidator.

 my $errors = validator(...)->(
   on => "...",
   should => sub { ... },
   because => "...",
 )->errors;

=cut 

sub validator {
    return Data::DynamicValidator->new(@_);
}

sub new {
    my ($class, $data) = @_;
    my $self = {
        _data   => $data,
        _errors => [],
        _level  => 0,
    };
    return bless $self => $class;
}

=method validate

Performs validation based on 'on', 'should', 'because' and optional 'each'
parameters. Returns the validator itself ($self), to allow further 'chain'
invocations. The validation will not be performed, if some errors already
have been detected.

=cut

sub validate {
    my ($self, %args) = @_;

    my $on      = $args{on     };
    my $should  = $args{should };
    my $because = $args{because};
    my $each    = $args{each   };

    croak("Wrong arguments: 'on', 'should', 'because' should be specified")
        if(!$on || !$should || !$because);

    warn "-- validating : $on \n" if DEBUG;

    my $errors = $self->{_errors};
    my $selection_results;
    if ( !@$errors ) {
        my $success;
        ($success, $selection_results) = $self->_apply($on, $should);
        $self->report_error($because, $on)
            unless $success;
    }
    # OK, now going to child rules if there is no errors
    if ( !@$errors && $each  ) {
        warn "-- no errors, will check children\n" if DEBUG;
        $self->_validate_children($selection_results, $each);
    }

    return $self;
}

=method report_error

The method is used for custom errors reporing. It is mainly usable in 'each'
closure.

 validator({ ports => [1000, 2000, 3000] })->(
   on      => '/ports/port:*',
   should  => sub { @_ > 0 },
   because => "At least one listening port should be defined",
   each    => sub {
     my $port;
     my $port_value = $port->();
     shift->report_error("Port value $port_value isn't acceptable, because < 1000")
       if($port_value < 1000);
   }
 );

=cut

sub report_error {
    my ($self, $reason, $path) = @_;
    $path //= $self->{_current_path};
    croak "Can't report error unless path is undefined"
        unless defined $path;
    push @{ $self->{_errors} }, Error->new($reason, $path);
}

=method is_valid

Checks, weather validator already has errors

=cut

sub is_valid { @{ $_[0]->{_errors} } == 0; }


=method errors

Returns internal array of errors

=cut

sub errors { $_[0]->{_errors} }

### private/implementation methods

sub _validate_children {
    my ($self, $selection_results, $each) = @_;
    my ($routes, $values) = @{$selection_results}{qw/routes values/};
    my $errors = $self->{_errors};
    my $data = $self->{_data};
    $self->{_level}++;
    for my $i (0 .. @$routes-1) {
        my $route = $routes->[$i];
        my $value = $values->[$i];
        my $label_for = { map { $_ => 1 } ($route->labels) };
        # prepare context
        my $pad = peek_sub($each);
        while (my ($var, $ref) = each %$pad) {
            my $var_name = substr($var, 1); # chomp sigil
            next unless exists $label_for->{$var_name};
            my $label_obj = Label->new($var_name, $route, $data);
            lexalias($each, $var, \$label_obj);
        }
        # call
        $self->{_current_path} = $route;
        $each->($self, local $_ = Label->new('_', $route, $data));
        last if(@$errors);
    }
    $self->{_level}--;
}


# Takes path-like expandable expression and returns hashref of path with corresponding
# values from data, e.g.

#  validator({ a => [5,'z']})->_select('/a/*');
#  # will return
#  # {
#  #   routes => ['/a/0', '/a/1'],
#  #   values => [5, z],
#  # }

# Actualy routes are presented by Path objects.

sub _select {
    my ($self, $expession) = @_;
    my $data = $self->{_data};
    my $routes = $self->_expand_routes($expession);
    my $values = [ map { $_->value($data) } @$routes ];
    return {
        routes => $routes,
        values => $values,
    };
}



# Takes xpath-like expandable expression and sorted array of exapnded path e.g.
#  validator({ a => [5,'z']})->_expand_routes('/a/*');
#  # will return [ '/a/0', '/a/1' ]
#  validator({ a => [5,'z']})->_expand_routes('/a');
#  # will return [ '/a' ]
#  validator({ a => { b => [5,'z'], c => ['y']} })->_expand_routes('/a/*/*');
#  # will return [ '/a/b/0', '/a/b/1', '/a/c/0' ]

sub _expand_routes {
    my ($self, $expession) = @_;
    warn "-- Expanding routes for $expession\n" if DEBUG;
    my @routes = ( Path->new($expession) );
    my $result = [];
    while (@routes) {
        my $route = shift(@routes);
        my $current = $self->{_data};
        my $elements = $route->components;
        my $i;
        my $can_be_accessed = 0;
        for ($i = 0; $i < @$elements; $i++) {
            $can_be_accessed = 0;
            my $element = $elements->[$i];
            # no futher examination if current value is undefined
            last unless defined($current);
            next if($element eq '');
            my $filter;
            ($element, $filter) = _filter($element);
            my $type = ref($current);
            my $generator;
            my $advancer;
            if ($element eq '*') {
                if ($type eq 'HASH') {
                    my @keys = keys %$current;
                    my $idx = 0;
                    $generator = sub {
                        while($idx < @keys) {
                            my $key = $keys[$idx++];
                            my $match = $filter->($current->{$key}, {key => $key});
                            return $key if($match);
                        }
                        return undef;
                    };
                } elsif ($type eq 'ARRAY') {
                    my $idx = 0;
                    $generator = sub {
                        while($idx < @$current) {
                            my $index = $idx++;
                            my $match = $filter->($current->[$index], {index => $index});
                            return $index if($match);
                        }
                        return undef;
                    };
                }
            }elsif ($type eq 'HASH' && exists $current->{$element}) {
                $advancer = sub { $current->{$element} };
            }elsif ($type eq 'ARRAY' && looks_like_number($element)
                && (
                    ($element >= 0 && $element < @$current)
                    || ($element < 0 && abs($element) <= @$current)
                   )
                ){
                $advancer = sub { $current->[$element] };
            }
            if ($generator) {
                while ( defined( my $new_element = $generator->()) ) {
                    my $new_path = dclone($route);
                    $new_path->components->[$i] = $new_element;
                    push @routes, $new_path;
                }
                $current = undef;
                last;
            }
            if ($advancer) {
                $current = $advancer->();
                $can_be_accessed = 1;
                next;
            }
            # the current element isn't hash nor array
            # we can't traverse further, because there is more
            # else current path
            $current = undef;
            $can_be_accessed = 0;
        }
        my $do_expansion = defined $current
            || ($can_be_accessed && $i == @$elements);
        warn "-- Expanded route : $route \n" if(DEBUG && $do_expansion);
        push @$result, $route if($do_expansion);
    }
    return [ sort @$result ];
}

sub _filter {
    my $element = shift;
    my $filter;
    my $condition_re = qr/(.+?)(\[(.+)\])/;
    my @parts = $element =~ /$condition_re/;
    if (@parts == 3 && defined($parts[2])) {
        $element = $parts[0];
        my $condition = $parts[2];
        $filter = Filter->new($condition);
    } else {
        $filter = sub { 1 }; # always true
    }
    return ($element, $filter);
}


# Takes the expandable expression and validation closure, then
# expands it, and applies the closure for every data piese,
# obtainted from expansion.

# Returns the list of success validation mark and the hash
# of details (obtained via _select).

sub _apply {
    my ($self, $on, $should) = @_;
    my $selection_results = $self->_select($on);
    my $values = $selection_results->{values};
    my $result = $values && @$values && $should->( @$values );
    return ($result, $selection_results);
};

1;
