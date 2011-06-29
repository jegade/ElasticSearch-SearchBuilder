#!perl

use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Exception;
use ElasticSearch::SearchBuilder;

my $a = ElasticSearch::SearchBuilder->new;

test_filters(
    'EMPTY AND|OR|NOT',

    '-and',
    { k => 1, -and => [] },
    { term => { k => 1 } },

    '-or',
    { k => 1, -or => [] },
    { term => { k => 1 } },

    '-not',
    { k => 1, -not => [] },
    { term => { k => 1 } },
);

test_filters(
    'SCALAR',
    '-and scalar',
    { -and => 1 },
    qr/little sense/,

    '-or scalar',
    { -or => 1 },
    qr/little sense/,

    '-not scalar',
    { -not => 1 },
    qr/little sense/
);

test_filters(
    'UNDEF',
    '-and undef',
    { -and => undef },
    qr/undef not supported/,

    '-or undef',
    { -or => undef },
    qr/undef not supported/,

    '-not undef',
    { -not => undef },
    qr/undef not supported/,
);

test_filters(
    'SINGLE AND|OR|NOT',

    '-and1',
    { -and => [ k => 1 ] },
    { term => { k => 1 } },

    '-or1',
    { -or  => [ k => 1 ] },
    { term => { k => 1 } },

    '-not',
    { -not => [ k => 1 ] },
    { not => { term => { k => 1 } } },
);

my %and_or = (
    and    => { and => [ { term => { a => 1 } }, { term => { b => 2 } } ] },
    or     => { or  => [ { term => { a => 1 } }, { term => { b => 2 } } ] },
    or_and => {
        and => [
            { or   => [   { term => { a => 1 } }, { term => { b => 2 } } ] },
            { term => { c => 3 } }
        ]
    },
    and_or => {
        or => [
            { and  => [   { term => { a => 1 } }, { term => { b => 2 } } ] },
            { term => { c => 3 } }
        ]
    },
    or_or => {
        or => [
            { or   => [   { term => { a => 1 } }, { term => { b => 2 } } ] },
            { term => { c => 3 } }
        ]
    },
);

test_filters(
    'BASIC AND|OR',

    '{and[]}',
    { -and => [ a => 1, b => 2 ] },
    $and_or{and},

    '[and[]]',
    [ -and => [ a => 1, b => 2 ] ],
    $and_or{and},

    '{or[]}',
    { -or => [ a => 1, b => 2 ] },
    $and_or{or},

    '[or[]]',
    [ -or => [ a => 1, b => 2 ] ],
    $and_or{or},

    '{and{}}',
    { -and => { a => 1, b => 2 } },
    $and_or{and},

    '[and{}]',
    [ -and => { a => 1, b => 2 } ],
    $and_or{and},

    '{or{}}',
    { -or => { a => 1, b => 2 } },
    $and_or{or},

    '[or{}]',
    [ -or => { a => 1, b => 2 } ],
    $and_or{or},
);

test_filters(
    'NESTED []{}',

    '{-or[[],kv]}',
    { -or => [ [ a => 1, b => 2 ], c => 3 ] },
    $and_or{or_or},

    '{-and[[],kv]}',
    { -and => [ [ a => 1, b => 2 ], c => 3 ] },
    $and_or{or_and},

    '[-or[[],kv]]',
    [ -or => [ [ a => 1, b => 2 ], c => 3 ] ],
    $and_or{or_or},

    '[-and[[],kv]]',
    [ -and => [ [ a => 1, b => 2 ], c => 3 ] ],
    $and_or{or_and},

    '{-and[-or[],kv]}',
    { -and => [ -or => [ a => 1, b => 2 ], c => 3 ] },
    $and_or{or_and},

    '{-or[-and[],kv]}',
    { -or => [ -and => [ a => 1, b => 2 ], c => 3 ] },
    $and_or{and_or},

    '[-and[-or[],kv]]',
    [ -and => [ -or => [ a => 1, b => 2 ], c => 3 ] ],
    $and_or{or_and},

    '[-or[-and[],kv]]',
    [ -or => [ -and => [ a => 1, b => 2 ], c => 3 ] ],
    $and_or{and_or},
);

test_filters(
    'MULTI OPS',

    'K[-and @V]',
    { k => [ -and => 1, 2, 3 ] },
    {   and => [
            { term => { k => 1 } },
            { term => { k => 2 } },
            { term => { k => 3 } }
        ]
    },

    'K[-and @{kv}]',
    { k => [ -and => { '^' => 1 }, { '^' => 2 }, { '^' => 3 } ] },
    {   and => [
            { prefix => { k => 1 } },
            { prefix => { k => 2 } },
            { prefix => { k => 3 } }
        ]
    },

    'K{=[-and,@v]}',
    { k     => { '=' => [ '-and', 1, 2 ] } },
    { terms => { k   => [ '-and', 1, 2 ] } },

    'K{-or{}}',
    { k => { -or => { '!=' => 1, '=' => 2 } } },
    qr/Unknown filter operator/,

    'K=>[-and[],{}]',
    { k => [ -and => [ 1, 2 ], { '^' => 3 } ] },
    { and => [ { terms => { k => [ 1, 2 ] } }, { prefix => { k => 3 } } ] },

    '-and[],kv,-or{}',
    { -and => [ a => 1, b => 2 ], x => 9, -or => { c => 3, d => 4 } },
    {   and => [
            { and  => [   { term => { a => 1 } }, { term => { b => 2 } } ] },
            { or   => [   { term => { c => 3 } }, { term => { d => 4 } } ] },
            { term => { x => 9 } }
        ]
    },

    '{-and[@kv,k[]],kv,-or{@kv,k[]}}',
    {   -and => [ a => 1, b => 2, k => [ 11, 12 ] ],
        x    => 9,
        -or => { c => 3, d => 4, l => { '=' => [ 21, 22 ] } }
    },
    {   and => [ {
                and => [
                    { term  => { a => 1 } },
                    { term  => { b => 2 } },
                    { terms => { k => [ 11, 12 ] } },
                ]
            },
            {   or => [
                    { term  => { c => 3 } },
                    { term  => { d => 4 } },
                    { terms => { l => [ 21, 22 ] } }
                ]
            },
            { term => { x => 9 } }
        ]
    },

    '{-or[@kv,k[]],kv,-and{@kv,k[]}}',
    {   -or => [ a => 1, b => 2, k => [ 11, 12 ] ],
        x   => 9,
        -and => { c => 3, d => 4, l => { '=' => [ 21, 22 ] } }
    },
    {   and => [ {
                and => [
                    { term  => { c => 3 } },
                    { term  => { d => 4 } },
                    { terms => { l => [ 21, 22 ] } }
                ]
            },
            {   or => [
                    { term  => { a => 1 } },
                    { term  => { b => 2 } },
                    { terms => { k => [ 11, 12 ] } },
                ]
            },
            { term => { x => 9 } }
        ]
    },

    '[-or[],-or[],kv,-and[],[@kv,-and[],{}',
    [   -or  => [ a => 1, b => 2 ],
        -or  => { c => 3, d => 4 },
        e    => 5,
        -and => [ f => 6, g => 7 ],
        [ h => 8,  i => 9, -and => [ k => 10, l => 11 ] ],
        { m => 12, n => 13 }
    ],
    {   or => [
            { or => [ { term => { a => 1 } }, { term => { b => 2 } } ] },
            { or => [ { term => { c => 3 } }, { term => { d => 4 } } ] },
            { term => { e => 5 } },
            { and => [ { term => { f => 6 } }, { term => { g => 7 } } ] },
            {   or => [
                    { term => { h => 8 } },
                    { term => { i => 9 } },
                    {   and => [
                            { term => { k => 10 } },
                            { term => { l => 11 } },
                        ]
                    }
                ]
            },
            { and => [ { term => { m => 12 } }, { term => { n => 13 } } ] }
        ]
    },

    'K[-and mixed []{} ]',
    {   foo => [
            '-and',
            [ { '^' => 'foo' }, { 'gt' => 'moo' } ],
            { '^' => 'bar', 'lt' => 'baz' },
            [ { '^' => 'alpha' }, { '^' => 'beta' } ],
            [ { '!=' => 'toto', '=' => 'koko' } ],
        ]
    },
    {   and => [ {
                or => [
                    { prefix => { foo => 'foo' } },
                    { range  => { foo => { gt => 'moo' } } }
                ]
            },
            {   and => [
                    { prefix => { foo => 'bar' } },
                    { range  => { foo => { lt => 'baz' } } }
                ]
            },
            {   or => [
                    { prefix => { foo => 'alpha' } },
                    { prefix => { foo => 'beta' } }
                ]
            },
            {   and => [
                    { not  => { term => { foo => 'toto' } } },
                    { term => { foo  => 'koko' } }
                ]
            }
        ]
    },

    '[-and[],-or[],k[-and{}{}]',
    [   -and => [ a => 1, b => 2 ],
        -or  => [ c => 3, d => 4 ],
        e => [ -and => { '^' => 'foo' }, { '^' => 'bar' } ],
    ],
    {   or => [
            { and => [ { term => { a => 1 } }, { term => { b => 2 } } ] },
            { or  => [ { term => { c => 3 } }, { term => { d => 4 } } ] },
            {   and => [
                    { prefix => { e => 'foo' } },
                    { prefix => { e => 'bar' } }
                ]
            }
        ]
    },

    '[-and[{},{}],-or{}]',
    [ -and => [ { foo => 1 }, { bar => 2 } ], -or => { baz => 3 } ],
    {   or => [
            { and => [ { term => { foo => 1 } }, { term => { bar => 2 } } ] },
            { term => { baz => 3 } }
        ]
    },

    # -and has only 1 following element, thus all still ORed
    'k[-and[]]',
    { k => [ -and => [ { '=' => 1 }, { '=' => 2 }, { '=' => 3 } ] ] },
    {   or => [
            { term => { k => 1 } },
            { term => { k => 2 } },
            { term => { k => 3 } }
        ]
    }
);

test_filters(
    'NOT',

    'not [k]',
    { -not => ['k'] },
    { not => { missing => { field => 'k' } } },

    'not{k=>v}',
    { -not => { k => 'v' } },
    { not => { term => { k => 'v' } } },

    'not{k{=v}}',
    { -not => { k    => { '=' => 'v' } } },
    { not  => { term => { k   => 'v' } } },

    'not[k=>v]',
    { -not => [ k => 'v' ] },
    { not => { term => { k => 'v' } } },

    'not[k{=v}]',
    { -not => [ k    => { '=' => 'v' } ] },
    { not  => { term => { k   => 'v' } } },

    'not{k1=>v,k2=>v}',
    { -not => { k1 => 'v', k2 => 'v' } },
    {   not => {
            and => [ { term => { k1 => 'v' } }, { term => { k2 => 'v' } } ]
        }
    },

    'not{k{=v,^v}}',
    { -not => { k => { '=' => 'v', '^' => 'v' } } },
    {   not => {
            and => [ { term => { k => 'v' } }, { prefix => { k => 'v' } } ]
        }
    },

    'not[k1=>v,k2=>v]',
    { -not => [ k1 => 'v', k2 => 'v' ] },
    {   not => {
            or => [ { term => { k1 => 'v' } }, { term => { k2 => 'v' } } ]
        }
    },

    'not[k{=v,^v}]',
    { -not => [ k => { '=' => 'v', '^' => 'v' } ] },
    {   not => {
            and => [ { term => { k => 'v' } }, { prefix => { k => 'v' } } ]
        }
    },

    'not not',
    { -not => { -not => { k => 'v' } } },
    { not => { not => { term => { k => 'v' } } } },

    'not !=',
    { -not => { k => { '!=' => 'v' } } },
    { not => { not => { term => { k => 'v' } } } },
);

done_testing;

#===================================
sub test_filters {
#===================================
    note "\n" . shift();
    while (@_) {
        my $name = shift;
        my $in   = shift;
        my $out  = shift;

        if ( ref $out eq 'Regexp' ) {
            throws_ok { $a->filter($in) } $out, $name;
        }
        else {
            eval {
                eq_or_diff scalar $a->filter($in), { filter => $out }, $name;
                1;
            }
                or die "*** FAILED TEST $name:***\n$@";
        }
    }
}
