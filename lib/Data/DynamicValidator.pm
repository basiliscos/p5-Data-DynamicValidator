package Data::DynamicValidator;
# ABSTRACT: XPath-like and Perl union for flexible perl data structures validation

use strict;
use warnings;

use Carp;
use Scalar::Util qw/looks_like_number/;
use Storable qw(dclone);

use aliased qw/Data::DynamicValidator::Error/;
use aliased qw/Data::DynamicValidator::Path/;

use overload
    fallback => 1,
    '&{}' => sub {
        my $self = shift;
        return sub { $self->validate(@_) }
    };

use parent qw/Exporter/;
our @EXPORT_OK = qw/validator/;

sub validator {
    return Data::DynamicValidator->new(@_);
}

sub new {
    my ($class, $data) = @_;
    my $self = {
        _data   => $data,
        _errors => [],
    };
    return bless $self => $class;
}

=method validate

=cut

sub validate {
    my ($self, %args) = @_;

    my $on      = $args{on     };
    my $should  = $args{should };
    my $because = $args{because};

    croak("Wrong arguments: 'on', 'should', 'because' should be specified")
        if(!$on || !$should || !$because);

    my $errors = $self->{_errors};
    if ( !@$errors ) {
        my $success = $self->apply($on, $should);
        push @$errors, Error->new($because, $on)
            unless $success;
    }

    return $self;
}

=method select

Takes xpath-like expandable expression and returns hashref of path with corresponding
values from data, e.g.

 validator({ a => [5,'z']})->select('/a/*');
 # will return
 # {
 #   routes => ['/a/0', '/a/1']  => 5,
 #   values => [5, z],
 # }

Actualy routes are presented by Path objects.

=cut

sub select {
    my ($self, $expession) = @_;
    my $data = $self->{_data};
    my $routes = $self->expand_routes($expession);
    my $values = [ map { $_->value($data) } @$routes ];
    return {
        routes => $routes,
        values => $values,
    };
}


=method expand_routes

Takes xpath-like expandable expression and sorted array of exapnded path e.g.

 validator({ a => [5,'z']})->expand_routes('/a/*');
 # will return [ '/a/0', '/a/1' ]

 validator({ a => [5,'z']})->expand_routes('/a');
 # will return [ '/a' ]

 validator({ a => { b => [5,'z'], c => ['y']} })->expand_routes('/a/*/*');
 # will return [ '/a/b/0', '/a/b/1', '/a/c/0' ]

=cut

sub expand_routes {
    my ($self, $expession) = @_;
    my @routes = ( Path->new($expession) );
    my $result = [];
    while (@routes) {
        my $route = shift(@routes);
        my $current = $self->{_data};
        my $elements = $route->components;
        for my $i (0 .. @$elements-1 ) {
            my $element = $elements->[$i];
            # no futher examination if current value is undefined
            last unless defined($current);
            next if($element eq '');
            my $generator;
            if (ref($current) eq 'HASH' && exists $current->{$element}) {
                $current = $current->{$element};
                next;
            }
            elsif (ref($current) eq 'HASH' && $element eq '*') {
                my @keys = keys %$current;
                my $idx = 0;
                $generator = sub {
                    return $keys[$idx++] if($idx < @keys);
                    return undef;
                };
            }
            elsif (ref($current) eq 'ARRAY' && looks_like_number($element)
                && $element < @$current) {
                $current = $current->[$element];
                next;
            }
            elsif (ref($current) eq 'ARRAY' && $element eq '*') {
                my $idx = 0;
                $generator = sub {
                    return $idx++ if($idx < @$current);
                    return undef;
                };
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
            # the current element isn't hash nor array
            # we can't traverse further, because there is more
            # else current path
            $current = undef;
        }
        push @$result, $route
            if(defined $current);
    }
    return [ sort @$result ];
}

sub apply {
    my ($self, $on, $should) = @_;
    my $selection_results = $self->select($on);
    my $result = $should->( @{ $selection_results->{values} } );
    return $result;
};

sub is_valid { @{ $_[0]->{_errors} } == 0; }

sub errors { $_[0]->{_errors} }

1;
