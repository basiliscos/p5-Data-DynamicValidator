use strict;
use warnings;

use Test::More;
use Test::Warnings;

use Data::DynamicValidator qw/validator/;

subtest 'simple-labels' => sub {
    my $data = {
        a => [
            { b => 5, },
            { c => 7, }
        ],
    };
    my $v = validator($data);
    my @vars;
    $v->(
        on      => '/hash1:*/array:*/hash2:*',
        should  => sub { @_ > 0 },
        because => '...ignored...',
        each    => sub {
            my ($hash1, $array, $hash2);
            push @vars, join('/', '', $hash1, $array, $hash2);
        },
    );
    ok $v->is_valid;
    is_deeply \@vars, ['/a/0/b', '/a/1/c'],
        "labels extraction/substitution works well";
};


done_testing;
