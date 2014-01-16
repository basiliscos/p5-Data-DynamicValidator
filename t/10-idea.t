use strict;
use warnings;

use Test::More;
use Test::Warnings;

use Data::DynamicValidator qw/validator/;

# sub test_validator($$@) {
#     my ($right_data, $wrong_data, %rules) = @_;
#     my $v_right = validator($right_data);
#     my $v_wrong = validator($wrong_data);
#     local $Test::Builder::Level = $Test::Builder::Level + 1;
#     ok $v_right->is_valid, "data is valid";
#     ok !$v_wrong->is_valid, "data is wrong";
# }

# test_validator(
#     { listen => [3000, 3001], },
#     { listen => [], },
#     on      => '/listen/*',
#     should  => sub { @_ > 0 },
#     because => "'listen' should define one or more listening ports",
# );

{
    my $data = { listen => [3000, 3001], };
    my $r;
    $r = validator($data)->apply('/listen/*'=> sub { @_ == 2 });
    ok $r, "positive simple path appliaction";
    $r = validator($data)->apply('/listen/*'=> sub { @_ > 2 });
    ok !$r, "simple path appliaction passed with false condition";
    $r = validator($data)->apply('/ABC/*' => sub { @_ == 0; });
    ok $r, "void path appliaction with positve condition";
    $r = validator($data)->apply('/ABC/*'=> sub { @_ > 0 });
    ok !$r, "void path appliaction with false condition";
}


done_testing;
