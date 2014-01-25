package Data::DynamicValidator::Label;
# ABSTRACT: Class holds label and allows extract current value under it in subject

use strict;
use warnings;

use overload fallback => 1,
    q/""/  => sub { $_[0]->to_string },
    q/&{}/ => sub {
        my $self = shift;
        return sub { $self->value }
    };

sub new {
    my ($class, $label_name, $path, $data) = @_;
    my $self = {
        _name  => $label_name,
        _path  => $path,
        _data  => $data,
    };
    bless $self => $class;
}

=method to_string

Stringizes to the value of label under current path

=cut

sub to_string {
    my $self = shift;
    $self->{_path}->named_component($self->{_name});
}

sub value {
    my $self = shift;
    $self->{_path}->value($self->{_data}, $self->{_name});
}

1;
