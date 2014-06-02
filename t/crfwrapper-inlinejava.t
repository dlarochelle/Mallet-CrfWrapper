#!perl
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More tests => 9;

BEGIN {
    use_ok( 'Mallet::CrfWrapper::InlineJava' )
}

use constant PATH_TO_TEST_RESOURCES => 'lib/Mallet/java/CrfUtils/src/test/resources/org/mediacloud/crfutils/';
use constant TEST_CRF_EXTRACTOR_MODEL => PATH_TO_TEST_RESOURCES . '/crf_extractor_model';
use constant TEST_INPUT_FILE => PATH_TO_TEST_RESOURCES . '/test_input.txt';
use constant TEST_OUTPUT_FILE => PATH_TO_TEST_RESOURCES . '/test_output.txt';

ok( -e TEST_CRF_EXTRACTOR_MODEL, 'Test extractor model exists' );
ok( -e TEST_INPUT_FILE, 'Test input file exists' );
ok( -e TEST_OUTPUT_FILE, 'Test output file exists' );

sub read_file_into_string($)
{
    my $filename = shift;

    local $/ = undef;
    open FILE, $filename or die "Couldn't open file: $!";
    binmode FILE;
    my $string = <FILE>;
    close FILE;

    return $string;
}

sub convert_crf_string_to_arrayref($)
{
    my $string = shift;

    # Format:
    #
    # excluded O=0.00008472 excluded=0.54451586 optional=0.45517693 required=0.00022249
    # excluded O=0.00000374 excluded=0.95802485 optional=0.04084096 required=0.00113045
    # ...

    my @result;
    my @lines = split("\n", $string);

    foreach my $line ( @lines ) {

        my @line_parts = split(' ', $line);

        my $prediction = $line_parts[0];
        my $probabilities = {};

        for (my $x = 1; $x <= $#line_parts; ++$x) {
            my ( $name, $value ) = split('=', $line_parts[$x]);
            $probabilities->{ $name } = $value + 0;
        }

        push( @result, { 'prediction' => $prediction, 'probabilities' => $probabilities } );
    }

    return \@result;
}

my $input = read_file_into_string( TEST_INPUT_FILE );
ok( $input, 'Input file has been read' );
my $expected_output = read_file_into_string( TEST_OUTPUT_FILE );
ok( $expected_output, 'Expected output file has been read' );
my $expected_output_arrayref = convert_crf_string_to_arrayref( $expected_output );
is( ref($expected_output_arrayref), ref([]), 'Processed expected output file is arrayref');

my @input_array = split( "\n", $input );

my $results = Mallet::CrfWrapper::InlineJava->run_model_inline_java_data_array( TEST_CRF_EXTRACTOR_MODEL, \@input_array );

is( ref($results), ref([]), 'Results is an arrayref' );
is_deeply( $results, $expected_output_arrayref, 'Results match' );
