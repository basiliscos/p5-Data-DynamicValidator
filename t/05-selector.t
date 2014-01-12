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
    return validator($data)->expand_routes($selector);
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


#my $r;


# my $r = _v({ a => [5,'z']}, '/a');
# is_deeply( $r, [5, 'z']);

done_testing;
