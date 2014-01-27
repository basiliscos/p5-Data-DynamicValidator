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
        $each->($self, local $_ = Label->new('_', $route, $data));
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
    my $condition_re = qr/\[(?<cond>.+)\]/;
    my @parts = split /(?=$condition_re)/, $element, 2;
    if (@parts == 1) {
        $filter = sub { 1 }; # always true
    } else {
        $element = $parts[0];
        my $condition = $parts[1];
        $filter = Filter->new($condition);
    }
    return ($element, $filter);
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
