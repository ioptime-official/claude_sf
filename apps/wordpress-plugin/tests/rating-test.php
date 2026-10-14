<?php
// Standalone test (no WordPress needed): php tests/rating-test.php
define( 'ACCOUNT_RATING_TESTING', true );
require __DIR__ . '/../account-rating.php';

$cases = array(
	array( 20000000, 'Hot' ),
	array( 10000000, 'Hot' ),
	array( 5000000, 'Warm' ),
	array( 999999, 'Undefined' ),
	array( 1000000, 'Warm' ),
	array( 'abc', 'Undefined' ),
);
$failed = 0;
foreach ( $cases as $c ) {
	$got = acct_rating_for( $c[0] );
	if ( $got !== $c[1] ) {
		fwrite( STDERR, "FAIL {$c[0]}: expected {$c[1]}, got $got\n" );
		$failed++;
	}
}
echo $failed ? "$failed failed\n" : "all passed\n";
exit( $failed ? 1 : 0 );
