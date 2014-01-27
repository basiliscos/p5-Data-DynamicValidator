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
    c => "bbb",
    c2 => 5,
    "dc/1" => [],
    d => undef,
    e => [ qw/e1 e2 z/ ],
};

subtest 'filter-in-hashrefs' => sub {
    my ($r, $values);

    ($r, $values) = validator($data)->apply('/*[key eq "d"]' => sub { 1 });
    ok $r;
    is @{ $values->{routes} }, 1 , "1 route selected (/d)";
    is $values->{routes}->[0]->to_string, '/d', "it is /d";
    is $values->{values}->[0], undef, "/d value is undef";

    ($r, $values) = validator($data)->apply('/`*[key =~ /d/]`' => sub { 1 });
    ok $r;
    is @{ $values->{routes} }, 2 , "1 route selected (/d and /dc/1)";
    is $values->{routes}->[0]->to_string, '/d', "it is /d";
    is $values->{routes}->[1]->to_string, '/dc/1', "it is /d/dc/1";
    is $values->{values}->[0], undef, "/d value is undef";
    is_deeply $values->{values}->[1] , [], "/dc/1 refers to empty array";

    ($r, $values) = validator($data)->apply('/*[value eq "bbb"]' => sub { 1 });
    ok $r;
    is @{ $values->{routes} }, 1 , "1 route selected (/c)";
    is $values->{routes}->[0]->to_string, '/c', "it is /c";
    is $values->{values}->[0], "bbb", "/c value is 'bbb'";
};


subtest 'filter-in-arrays' => sub {
    my ($r, $values);

    ($r, $values) = validator($data)->apply('/e/`*[value =~ /^e/]`' => sub { 1 });
    ok $r;
    is @{ $values->{routes} }, 2 , "2 route selected (/e/{e1,e2})";
};


done_testing;
