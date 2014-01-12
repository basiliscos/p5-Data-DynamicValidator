package Data::DynamicValidator::Path;

use strict;
use warnings;

use Carp;

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
    my @named_elements = ();
    for my $i (0..@elements-1) {
        my @parts = split(':', $elements[$i]);
        if (@parts > 1) {
            $elements[$i] = $parts[1];
            push @named_elements, {
                index => $i,
                name  => $parts[0],
            };
        }
    }
    $self->{_components} = \@elements;
    $self->{_labels    } = \@named_elements;
}

sub components { shift->{_components} }

sub to_string { join('/', @{ shift->{_components} })}

sub labels {
    map { $_->{name} } @{ shift->{_labels} };
}

sub named_route {
    my ($self, $label) = @_;
    for my $i ( 0 .. @{ $self->{_labels} } ) {
        my $l = $self->{_labels}->[$i];
        if ($l->{name} eq $label) {
            return $self->_clone_to($l->{index});
        }
    }
    croak("No label '$label' in path '$self'");
}

sub _clone_to {
    my ($self, $index) = @_;
    my @components;
    for my $i (0 .. $index) {
        push @components, $self->{_components}->[$i]
    }
    for my $label ( @{ $self->{_labels} } ) {
        my $i = $label->{index};
        $components[$i] = join(':', $label->{name}, $components[$i] )
            if( $i <= $index);
    }
    my $path = join('/', @components);
    return Data::DynamicValidator::Path->new($path);
}

1;
