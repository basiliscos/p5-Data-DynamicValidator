package Data::DynamicValidator::Filter;
# ABSTRACT: Class responds for filtering data paths

use strict;
use warnings;

use Eval::Closure;
use Try::Tiny;

use constant DEBUG => $ENV{DATA_DYNAMICVALIDATOR_DEBUG} || 0;

use overload
    fallback => 1,
    '&{}' => sub {
        my $self = shift;
        return sub { $self->filter(@_) }
    };

sub new {
    my ($class, $condition) = @_;
    my $self = {
        _condition => $condition
    };
    bless $self => $class;
}

sub _prepare {
    my ($self, $data, $context) = @_;
    my %environment;
    my $c = $self->{_condition};
    my $type = ref($data);
    if ($c =~ /\bsize\b/) {
        my $value;
        if ($type eq 'HASH') {
            $value = sub { scalar keys %$data };
        } elsif ($type eq 'ARRAY') {
            $value = sub { scalar @$data };
        }
        if ($value) {
            my $val = $value->();
            $environment{'$size'} = \$val;
        }
    }
    if ($c =~ /\bvalue\b/) {
        $environment{'$value'} = \$data if(defined($data));
    }
    if ($c =~ /\bindex\b/ && ref($context) eq 'HASH'
        && defined($context->{index}) ) {
        $environment{'$index'} = \$context->{index};
    }
    if ($c =~ /\bkey\b/ && ref($context) eq 'HASH'
        && defined($context->{key}) ) {
        $environment{'$key'} = \$context->{key};
    }
    # substitute to environment values in condition
    for (keys %environment) {
        s/^\$//;
        $c =~ s/\b($_)\b/\$$1/;
    }
    return ($c, \%environment);
}

sub filter {
    my ($self, $data, $context) = @_;

    my ($c, $environment) = $self->_prepare($data, $context);
    my $source = "sub { $c }";
    warn "-- evaluating condition as source: $source \n" if(DEBUG);

    # evaluation phase
    my $result = 0;
    try {
        my $code = eval_closure(
            source      => $source,
            environment => $environment,
        );
        $result = $code->();
    } catch {
        warn "-- exection has been thrown, considering false: $_ \n" if(DEBUG);
    };
    warn "-- result: $result: \n" if(DEBUG);
    return $result;
}


1;
