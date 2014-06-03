#!perl
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More tests => 10;

BEGIN {
    use_ok( 'Mallet::CrfWrapper' );
    use_ok( 'Mallet::CrfWrapper::InlineJava' );
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

my $input = read_file_into_string( TEST_INPUT_FILE );
ok( $input, 'Input file has been read' );
my $expected_output = read_file_into_string( TEST_OUTPUT_FILE );
ok( $expected_output, 'Expected output file has been read' );
my $expected_output_arrayref = Mallet::CrfWrapper::convert_crf_string_to_arrayref( $expected_output );
is( ref($expected_output_arrayref), ref([]), 'Processed expected output file is arrayref');

my @input_array = split( "\n", $input );

my $results = Mallet::CrfWrapper::InlineJava->run_model_inline_java_data_array( TEST_CRF_EXTRACTOR_MODEL, \@input_array );

is( ref($results), ref([]), 'Results is an arrayref' );
is_deeply( $results, $expected_output_arrayref, 'Results match' );
