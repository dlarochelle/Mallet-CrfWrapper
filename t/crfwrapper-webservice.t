#!perl
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More tests => 12;

BEGIN {
    use_ok( 'Mallet::CrfWrapper' );
    use_ok( 'Mallet::CrfWrapper::WebService' );
}

use constant PATH_TO_TEST_RESOURCES => 'lib/Mallet/java/CrfUtils/src/test/resources/org/mediacloud/crfutils/';
use constant TEST_CRF_EXTRACTOR_MODEL => PATH_TO_TEST_RESOURCES . '/crf_extractor_model';
use constant TEST_INPUT_FILE => PATH_TO_TEST_RESOURCES . '/test_input.txt';
use constant TEST_OUTPUT_FILE => PATH_TO_TEST_RESOURCES . '/test_output.txt';
my $test_port = 8551;

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

# Compile and start Java's web service
my $pom_path = 'lib/Mallet/java/CrfUtils/pom.xml';

say STDERR "Compiling CRF web service...";
my $mvn_compile_result = `mvn -f $pom_path compile`;
is( $?, 0, 'mvn compile succeeded' );
say STDERR $mvn_compile_result;

say STDERR "Running CRF web service's unit tests...";
my $mvn_test_result = `mvn -f $pom_path test`;
is( $?, 0, 'mvn test succeeded' );
say STDERR $mvn_test_result;

say STDERR "Starting CRF web service...";
my $command = "mvn -f $pom_path exec:java -Dcrf.extractorModelPath=" . TEST_CRF_EXTRACTOR_MODEL . " -Dcrf.httpListen=127.0.0.1:$test_port 1>&2";

my $pid = fork();
die "unable to fork: $!" unless defined($pid);
unless ($pid) {  # child
    setpgrp(0, 0);
    exec($command);
    die "unable to exec: $!";
}
# parent continues here, pid of child is in $pid

say STDERR "Waiting for CRF web service to start up...";
sleep( 10 );    # wait for the process to fire up properly

# Test the web service
say STDERR "Testing CRF web service with sample data...";
my $web_service_url = "http://127.0.0.1:$test_port/";
Mallet::CrfWrapper::WebService::set_webservice_url( $web_service_url );
my $results = Mallet::CrfWrapper::WebService->run_model_inline_java_data_array( TEST_CRF_EXTRACTOR_MODEL, \@input_array );

is( ref($results), ref([]), 'Results is an arrayref' );
is_deeply( $results, $expected_output_arrayref, 'Results match' );

# Kill the Java web service
say STDERR "Shutting down CRF web service at PID $pid...";
kill 9, -$pid;

say STDERR "Done.";
