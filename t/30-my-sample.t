use strict;
use warnings;

use Test::More;
use Test::Warnings;

use Data::DynamicValidator qw/validator/;

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
    dispatcher => {
    	    maximal_input_size => 4096,
    },

    mojolicious => {
    	hypnotoad => {
            pid_file => '/tmp/hypnotoad-ng.pid',
            listen  => [
                'http://localhost:3000',
            ],
        },
    },

    redis => {
        host => '127.0.0.1',
        port => 6379,
    },

    finalizer => {
        job_ttl => 3600,
    },

    queue_processor => {
        sp_ping_timeout             => 1,
        sp_idle                     => 5,
        sp_max_ping_failures        => 10,
        sp_max_unknown_failures     => 1,
        sp_request_timeout          => 5,
        client_callback_timeout     => 1,
        host                        => '127.0.0.1',
        port                        => 5000,
    },
    daemon => {
       child_max_wait => 10,
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
                on      => "/service_points/*/$f/job_slots",
                should  => sub { $_[0] && defined($_[0]->[0]) },
                because => "at least 1 service point should be defined for feature '$f'",
            )
        }
    )->errors;
    is_deeply $errors, [], "no errors on valid data";
};

done_testing;
