<?php
/**
 * Plugin Name: Account Rating Badge
 * Description: [account_rating revenue="5000000"] shortcode that renders a Hot/Warm/Cold badge.
 * Version: 0.1.0
 */

if ( ! defined( 'ABSPATH' ) && ! defined( 'ACCOUNT_RATING_TESTING' ) ) {
	exit;
}

function acct_rating_for( $revenue ) {
	$revenue = (float) $revenue;
	if ( $revenue >= 10000000 ) {
		return 'Hot';
	}
	if ( $revenue >= 1000000 ) {
		return 'Warm';
	}
	return 'Cold';
}

function acct_rating_shortcode( $atts ) {
	$atts   = shortcode_atts( array( 'revenue' => 0 ), $atts, 'account_rating' );
	$rating = acct_rating_for( $atts['revenue'] );
	return '<span class="account-rating account-rating--' . esc_attr( strtolower( $rating ) ) . '">' . esc_html( $rating ) . '</span>';
}

if ( function_exists( 'add_shortcode' ) ) {
	add_shortcode( 'account_rating', 'acct_rating_shortcode' );
}
