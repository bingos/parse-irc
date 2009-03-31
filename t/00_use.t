use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
	use_ok( 'Parse::IRC' );
}

diag( "Testing Parse::IRC $Parse::IRC::VERSION, Perl $], $^X" );
