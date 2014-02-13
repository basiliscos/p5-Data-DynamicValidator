my $cfg = {
    webservices => {
        convert => {
            timeout => 20,
        },
        thumbnail => {
            pagebox => 'TRIMBOX',
            width   => 100,
            height  => 100,
        },
	preview => {
	    timeout => 20,
	},
        optimize => {
            timeout => 20,
        },
    },
};

my $errors = validator($cfg)->(
    on      => '/wookie_webservices',
    should  => sub { @_ == 1 },
    because => 'The "wookie_webservices" URL should be specified',
)->rebase('/wookie_webservices' => sub {
        shift->(
            on      => '/convert/timeout',
            should  => sub { @_ == 1 && $_[0] > 0 },
            because => 'Convert timeout (positive value) should be specified',
        )->(
            on      => '/preview/timeout',
            should  => sub { @_ == 1 && $_[0] > 0 },
            because => 'Preview timeout (positive value) should be specified',
        )->(
            on      => '/optimize/timeout',
            should  => sub { @_ == 1 && $_[0] > 0 },
            because => 'Preview timeout (positive value) should be specified',
        )->rebase('/thumbnail' => sub {
                shift->(
                    on      => '/pagebox',
                    should  => sub { @_ == 1 && $_[0] > 0 },
                    because => 'Thumbnail pagebox should be specified (e.g. TRIMBOX)',
                )->(
                    on      => '/width',
                    should  => sub { @_ == 1 && $_[0] > 0 },
                    because => 'Thumbnail width should be specified',
                )->(
                    on      => '/height',
                    should  => sub { @_ == 1 && $_[0] > 0 },
                    because => 'Thumbnail height should be specified',
                );
            }
        );
    },
)->errors;

#########
#########

#validation of data like:
my $x = [ a => 5, b => 8 ];
