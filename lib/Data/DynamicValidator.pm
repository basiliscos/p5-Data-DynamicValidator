package Data::DynamicValidator;

use strict;
use warnings;

use Carp;
use Scalar::Util qw/looks_like_number/;

use overload
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

sub validate {
    my ($self, %args) = @_;

    my $on      = $args{on     };
    my $should  = $args{should };
    my $because = $args{because};

    croak("Wrong arguments: 'on', 'should', 'because' should be specified")
        if(!$on || !$should || !$because);
    
}

=method select

Takes xpath-like expandable expression and returns hashref of path with corresponding
values from data, e.g.

 validator({ a => [5,'z']})->select('/a/*');
 # will return
 # {
 #   '/a/0' => 5,
 #   '/a/1' => 'z',
 # }


 validator({ a => [5,'z']})->select('/a');
 # will return
 # {
 #   '/a' => [5, 'z']
 # }

 validator({ a => { b => [5,'z'], c => ['y']} })->select('/a/*/*');
 # will return
 # {
 #   '/a/b/0' => 5,
 #   '/a/b/1' => 'z',
 #   '/a/c/0' => 'y',
 # }

=cut

sub select {
    my ($self, $expession) = @_;
    my @routes = split('/', $expession);
    my $result = {};
    my $current = $self->{_data};
    for my $i (0 .. @routes-1 ) {
        my $element = $routes[$i];
        last unless defined($current);
        next if($element eq '');
        if (ref($current) eq 'HASH' && exists $current->{$element}) {
            $current = $current->{$element};
            next;
        }
        if ($element eq '*') {
        }
    }
    return $result;
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
    my @routes = ($expession);
    my $result = [];
    while (@routes) {
        my $route = shift(@routes);
        my $current = $self->{_data};
        my @elements = split('/', $route);
        for my $i (0 .. @elements-1 ) {
            my $element = $elements[$i];
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
                    my @new_elements = @elements;
                    $new_elements[$i] = $new_element;
                    my $new_route = join('/', @new_elements);
                    push @routes, $new_route;
                }
                $current = undef;
                last;
            }
            # the current element isn't hash nor array
            # we can't traverse further, because there is more
            # else current path
            $current = undef;
        }
        push @$result, $route if(defined $current);
    }
    return [ sort @$result ];
}

sub is_valid {
    my $self = shift;
    @{ $self->{_errors} } == 0;
}

1;
