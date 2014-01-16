use strict;
use warnings;

use Test::More;
use Test::Warnings;

use Data::DynamicValidator qw/validator/;

subtest 'route-application' => sub {
    my $data = { listen => [3000, 3001], };
    my $r;
    $r = validator($data)->apply('/listen/*' => sub { @_ == 2 });
    ok $r, "positive simple path appliaction";
    $r = validator($data)->apply('/listen/*' => sub { @_ > 2 });
    ok !$r, "simple path appliaction passed with false condition";
    $r = validator($data)->apply('/ABC/*' => sub { @_ == 0; });
    ok $r, "void path appliaction with positve condition";
    $r = validator($data)->apply('/ABC/*' => sub { @_ > 0 });
    ok !$r, "void path appliaction with false condition";
};

subtest 'simple-error' => sub {
    my $data = { listen => [3000, 3001], };
    my $v;
    $v = validator($data)->(
        on      => '/*',
        should  => sub { 0; },
        because => 'I want it fails',
    );
    ok $v, "we always return self";
    ok !$v->is_valid, 'failed by should rule';
    is @{ $v->errors }, 1, "got exactly 1 error";
    is $v->errors->[0]->reason, 'I want it fails', 'got error reason';
};

sub test_validator($$@) {
    my ($right_data, $wrong_data, %rules) = @_;
    my $v_right = validator($right_data);
    my $v_wrong = validator($wrong_data);
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    ok $v_right->validate(%rules)->is_valid, "valid on valid rules";
    ok !$v_wrong->validate(%rules)->is_valid, "invalid on invalid rules";
}

test_validator(
    { listen => [3000, 3001], },
    { listen => [], },
    on      => '/listen/*',
    should  => sub { @_ > 0 },
    because => "'listen' should define one or more listening ports",
);


done_testing;
