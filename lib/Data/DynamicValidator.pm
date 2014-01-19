package Data::DynamicValidator;
{
  $Data::DynamicValidator::VERSION = '0.01';
}
#ABSTRACT: XPath-like and Perl union for flexible perl data structures validation

use strict;
use warnings;

use Carp;
use Devel::LexAlias qw(lexalias);
use PadWalker qw(peek_sub);
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

use constant DEBUG => $ENV{DATA_DYNAMICVALIDATOR_DEBUG} || 0;

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
        ($success, $selection_results) = $self->apply($on, $should);
        push @$errors, Error->new($because, $on)
            unless $success;
    }
    # OK, now going to child rules if there is no errors
    if ( !@$errors && $each  ) {
        warn "-- no errors, will check children\n" if DEBUG;
        $self->_validate_children($selection_results, $each);
    }

    return $self;
}

sub _validate_children {
    my ($self, $selection_results, $each) = @_;
    my ($routes, $values) = @{$selection_results}{qw/routes values/};
    my $errors = $self->{_errors};
    $self->{_level}++;
    for my $i (0 .. @$routes-1) {
        my $route = $routes->[$i];
        my $value = $values->[$i];
        my $last_component = $route->components->[-1];
        my $label_of = {
            map { $_ => $route->named_component($_) }
                ($route->labels)
        };
        # prepare context
        my $pad = peek_sub($each);
        while (my ($var, $ref) = each %$pad) {
            my $var_name = substr($var, 1); # chomp sigil
            next unless exists $label_of->{$var_name};
            my $label_name = $label_of->{$var_name};
            lexalias($each, $var, \$label_name);
        }
        # call
        $each->($self, local $_ = $last_component);
        last if(@$errors);
    }
    $self->{_level}--;
}


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



sub expand_routes {
    my ($self, $expession) = @_;
    warn "-- Expanding routes for $expession\n" if DEBUG;
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
        warn "-- Expanded route : $route \n" if(DEBUG && defined($current));
        push @$result, $route
            if(defined $current);
    }
    return [ sort @$result ];
}

sub apply {
    my ($self, $on, $should) = @_;
    my $selection_results = $self->select($on);
    my $result = $should->( @{ $selection_results->{values} } );
    return ($result, $selection_results);
};

sub is_valid { @{ $_[0]->{_errors} } == 0; }

sub errors { $_[0]->{_errors} }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::DynamicValidator - XPath-like and Perl union for flexible perl data structures validation

=head1 VERSION

version 0.01

=head1 METHODS

=head2 validate

=head2 select

Takes xpath-like expandable expression and returns hashref of path with corresponding
values from data, e.g.

 validator({ a => [5,'z']})->select('/a/*');
 # will return
 # {
 #   routes => ['/a/0', '/a/1']  => 5,
 #   values => [5, z],
 # }

Actualy routes are presented by Path objects.

=head2 expand_routes

Takes xpath-like expandable expression and sorted array of exapnded path e.g.

 validator({ a => [5,'z']})->expand_routes('/a/*');
 # will return [ '/a/0', '/a/1' ]

 validator({ a => [5,'z']})->expand_routes('/a');
 # will return [ '/a' ]

 validator({ a => { b => [5,'z'], c => ['y']} })->expand_routes('/a/*/*');
 # will return [ '/a/b/0', '/a/b/1', '/a/c/0' ]

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
