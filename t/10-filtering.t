use strict;
use warnings;

use Test::More;
use Test::Warnings;

use Data::DynamicValidator qw/validator/;

my $data = {
    a => [
        { b => 4},
        undef,
    ],
    "dc/1" => [],
    d => undef,
};

my ($r, $values);

($r, $values) = validator($data)->apply('/*[key eq "d"]' => sub { 1 });
ok $r;
is @{ $values->{routes} }, 1 , "1 route selected (/d)";
is $values->{routes}->[0]->to_string, '/d', "it is /d";
is $values->{values}->[0], undef, "/d values is undef";

($r, $values) = validator($data)->apply('/`*[key =~ /d/]`' => sub { 1 });
ok $r;
is @{ $values->{routes} }, 2 , "1 route selected (/d and /dc/1)";
is $values->{routes}->[0]->to_string, '/d', "it is /d";
is $values->{routes}->[1]->to_string, '/dc/1', "it is /d/dc/1";
is $values->{values}->[0], undef, "/d values is undef";
is_deeply $values->{values}->[1] , [], "/dc/1 refers to empty array";


done_testing;
