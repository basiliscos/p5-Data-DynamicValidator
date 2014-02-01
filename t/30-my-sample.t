use strict;
use warnings;

use Test::More;
use Test::Warnings;

use List::MoreUtils qw/all/;
use Data::DynamicValidator qw/validator/;
use Net::hostent;

my $cfg = {

    features => [
        "a/f",
        "pdftoolbox/preflight",
        "pdftoolbox/splitpdf",
    ],

    service_points => {
        localhost => {
            "a/f" => {
                job_slots => 3,
            },
            "pdftoolbox/preflight" => {
                job_slots => 5,
            },
            "pdftoolbox/splitpdf" => {
                job_slots => 5,
            },
        },
        "127.0.0.1" => {
            "pdftoolbox/splitpdf" => {
                job_slots => 5,
            },
        },

    },

    mojolicious => {
    	hypnotoad => {
            pid_file => '/tmp/hypnotoad-ng.pid',
            listen  => [
                'http://localhost:3000',
            ],
        },
    },
};


subtest 'my-positive' => sub {
    my $errors = validator($cfg)->(
        on      => '/features/*',
        should  => sub { @_ > 0 },
        because => "at least one feature should be defined",
        each    => sub {
            my $f = $_->();
            shift->(
                on      => "/service_points/*/`$f`/job_slots",
                should  => sub { defined($_[0]) && $_[0] > 0 },
                because => "at least 1 service point should be defined for feature '$f'",
            )
        }
    )->(
        on      => '/service_points/sp:*',
        should  => sub { @_ > 0 },
        because => "at least one service point should be defined",
        each    => sub {
            my $sp;
            shift->report_error("SP '$sp' isn't resolvable")
                unless gethost($sp);
        }
    )->(
        on      => '/service_points/sp:*/f:*',
        should  => sub { @_ > 0 },
        because => "at least one feature under service point should be defined",
        each    => sub {
            my ($sp, $f);
            shift->(
                on      => "/features/`*[value eq '$f']`",
                should  => sub { 1 },
                because => "Feature '$f' of service point '$sp' should be decrlared in top-level features list",
            )
        },
    )->(
        on      => '/mojolicious/hypnotoad/pid_file',
        should  => sub { @_ == 1 },
        because => "hypnotoad pid_file should be defined",
    )->(
        on      => '/mojolicious/hypnotoad/listen/*',
        should  => sub { @_ > 0 },
        because => "hypnotoad listening interfaces defined",
    )->errors;
    is_deeply $errors, [], "no errors on valid data";
};

done_testing;
