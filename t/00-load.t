#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Mallet::CrfWrapper' ) || print "Bail out!\n";
}

diag( "Testing Mallet::CrfWrapper $Mallet::CrfWrapper::VERSION, Perl $], $^X" );
