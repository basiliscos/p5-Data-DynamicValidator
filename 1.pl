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
        job_ttl => 3600, # time-to-live for job in 'complete' queue, in seconds
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

### EITHER!!!

my $dv = DynamicValidator->new($cfg);

$dv->(
    on      => '/features/*',
    should  => sub { @$_ > 0 },
    because => "at least one feature should be defined",
    each    => sub {
        $_->(
            on      => "/service_points/*/$_/job_slots",
            should  => sub { $_ && defined($_->[0]) },
            because => "at least 1 service point should be defined for feature '$_'",
        )
    }
)->(
    on      => '/service_points/*:sp/*:f',
    should  => sub { @$_ > 0 },
    because => "at least one service point with feature should be defined",
    each    => sub {
        $_->(
            on      => "/features/$f",
            should  => sub { $_ && defined($_->[0]) },
            because => "$sp feature $f should be decrlared in top-level features list",
        )->(
            on      => "$_/job_slots*",
            should  => sub { $_ && $_->[0] > 0 },
            because => "$sp/$f should have positive job slot number",
        )
    }
)->(
    on      => '/redis',
    should  => sub { @$_ > 0 },
    because => 'Connection to redis should be defined',
    either  => sub {
        $_->(
            on     => '/redis/unix_socket'
            should => sub { @$_ > 0 },
            because => 'unix socket redis connection should be defined'
        )->(
            on     => '/redis/{host,port}'
            should => sub { @$_ > 0 },
            because => 'host:post redis connection should be defined'
        )
    }
);

# DV : blessed sub?
# on the sub call, the $_ points to current node or undef. Many selected items will be error
# $_ (and DV overloads "to_string" to the last component of the path on the currently slected node
# .....
# 'on'      : x-path, which selects data. Always an array
# 'should'  : injects as $_ the array (many be empty) of values, selected by 'on' rule
# 'because' : the text description for the error, if 'should' rule fails
# 'each'    : executes sub, for each of selected notes on, $_ points to DV, with setted current selected node.
# 


# # .................
# # check, that we have at lest one feature
# _c('/features/*')
#     ->(sub { @$_ > 0 } => "at least one feature should be defined")
#     ->[ sub { _c("/service_points/*/$_/job_slots")
#         ->("at least 1 service point should be defined for feature $_") } ];

# ## or ?
#     ->[
#         _c("/service_points/*/$_/job_slots")
#             ->("at least 1 service point should be defined for feature $_")
#     ];


# # validation: all declared job slot type have been previously declared among features;
# # every job_slot value is an positive number
# _c('/service_points/*(?sp)/*(?f)')->{
#     sub { _c{ "/features/$f" } }
#         => "$sp feature $f should be decrlared in top-level features list"
# } + _c('/job_slots/*')
#     ->[ sub { $_ > 0 } => "$sp/$f should have at least one job slot" ];

