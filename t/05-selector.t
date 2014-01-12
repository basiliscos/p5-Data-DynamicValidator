use strict;
use warnings;

use Test::More;
use Test::Warnings;

use Data::DynamicValidator qw/validator/;

sub _v {
    my ($data, $selector) = @_;
    return validator($data)->select($selector);
};

sub _e {
    my ($data, $selector) = @_;
    my $routes = [
        map { "$_" } @{ validator($data)->expand_routes($selector) }
    ];
    return $routes;
}

# routes expansion
{
    my $r;

    $r = _e({ a => [5,'z']}, '/a');
    is_deeply( $r, ['/a']);

    $r = _e({ a => [5,'z']}, '/a/0');
    is_deeply( $r, ['/a/0']);

    $r = _e({ a => [5,'z']}, '/a/1');
    is_deeply( $r, ['/a/1']);

    $r = _e({ a => [5,'z']}, '/a/5');
    is_deeply( $r, []);

    $r = _e({ a => [5,'z']}, '/a/-2');
    is_deeply( $r, ['/a/-2']);

    $r = _e({ a => [5,'z']}, '/a/-1');
    is_deeply( $r, ['/a/-1']);

    $r = _e({ a => [5,'z']}, '/a/-3');
    is_deeply( $r, []);

    $r = _e({ a => [5,'z']}, '/a/*');
    is_deeply( $r, ['/a/0', '/a/1']);

    $r = _e({ a => { b => 2, c => 3, 1 => 4}}, '/a/*');
    is_deeply( $r, ['/a/1', '/a/b', '/a/c']);

    $r = _e({ a => { b => [5,'z']} }, '/a/*/*');
    is_deeply( $r, ['/a/b/0', '/a/b/1']);

    $r = _e({ a => { b => [5,'z']} }, '/*/*/*');
    is_deeply( $r, ['/a/b/0', '/a/b/1']);

    $r = _e({ a => { b => [5,'z']} }, '/*/*/1');
    is_deeply( $r, ['/a/b/1']);

    $r = _e([{ a => { b => [5,'z']} }], '/*/*/*/1');
    is_deeply( $r, ['/0/a/b/1']);
}

# check named routes
{
    my $r;
    $r = validator({ a => { b => [5,'z']} })->expand_routes('/*/v2:*/*');
    is_deeply [ map { "$_" } @$r], ['/a/b/0', '/a/b/1'];
    is $r->[0]->named_route('v2')->to_string, '/a/b', 'has v2 at 1st route';
    is $r->[1]->named_route('v2')->to_string, '/a/b', 'has v2 at 2nd route';

    $r = validator({ a => { b => [5,'z']} })->expand_routes('/v1:*/v2:*/v3:0');
    is_deeply [ map { "$_" } @$r], ['/a/b/0'], 'expands correctly';
    my $p = $r->[0];
    is_deeply [$p->labels], ['v1', 'v2', 'v3'], 'all labels mentioned';

    is $p->named_route('v1')->to_string, '/a'    , 'v1 present';
    is $p->named_route('v2')->to_string, '/a/b'  , 'v2 present';
    is $p->named_route('v3')->to_string, '/a/b/0', 'v3 present';
}


#my $r;


# my $r = _v({ a => [5,'z']}, '/a');
# is_deeply( $r, [5, 'z']);

done_testing;
