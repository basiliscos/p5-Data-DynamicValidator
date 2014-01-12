package Data::DynamicValidator::Path;

use strict;
use warnings;

use Carp;
use Scalar::Util qw/looks_like_number/;

use overload fallback => 1, q/""/ => sub { $_[0]->to_string };

sub new {
    my ($class, $path) = @_;
    my $self = { };
    bless $self => $class;
    $self->_build_components($path);
    return $self;
}

sub _build_components {
    my ($self, $path) = @_;
    my @elements = split('/', $path);
    for my $i (0..@elements-1) {
        my @parts = split(':', $elements[$i]);
        if (@parts > 1) {
            $elements[$i] = $parts[1];
            $self->{_labels}->{ $parts[0] } = $i;
        }
    }
    $self->{_components} = \@elements;
}

sub components { shift->{_components} }

sub to_string { join('/', @{ shift->{_components} })}

sub labels {
    my $self = shift;
    my $labels = $self->{_labels};
    sort { $labels->{$a} <=> $labels->{$b} } keys %$labels;
}

sub named_route {
    my ($self, $label) = @_;
    croak("No label '$label' in path '$self'")
        unless exists $self->{_labels}->{$label};
    return $self->_clone_to($self->{_labels}->{$label});
}

sub _clone_to {
    my ($self, $index) = @_;
    my @components;
    for my $i (0 .. $index) {
        push @components, $self->{_components}->[$i]
    }
    while ( my ($name, $idx) = each(%{ $self->{_labels} })) {
        $components[$idx] = join(':', $name, $components[$idx])
            if( $idx <= $index);
    }
    my $path = join('/', @components);
    return Data::DynamicValidator::Path->new($path);
}

sub value {
    my ($self, $data, $label) = @_;
    croak("No label '$label' in path '$self'")
        if(defined($label) && !exists $self->{_labels}->{$label});
    my $idx = defined($label)
        ? $self->{_labels}->{$label}
        : @{ $self->{_components} } - 1;
    my $value = $data;
    for my $i (1 .. $idx) {
        my $element = $self->{_components}->[$i];
        if (ref($value) && ref($value) eq 'HASH' && exists $value->{$element}) {
            $value = $value->{$element};
            next;
        }
        elsif (ref($value) && ref($value) eq 'ARRAY'
            && looks_like_number($element) && $element < @$value) {
            $value = $value->[$element];
            next;
        }
        croak "I don't know how to get element#$i ($element) at $self";
    }
    return $value;
}

1;
