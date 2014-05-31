package Mallet::CrfWrapper::WebService;

#
# Package to access CRF model runner via web service
#

use strict;
use warnings;

use MediaWords::Util::Config;
use MediaWords::Util::CrfExtractor;
use Mallet::CrfWrapper;

use MediaWords::Util::Web;
use HTTP::Request;
use HTTP::Status qw(:constants);
use Encode;
use URI;
use JSON;

use Data::Dumper;

use constant DEFAULT_CRF_PORT => 8441;

#
# Helpers
#

sub _fatal_error($)
{
    my $error_message = shift;
    Mallet::CrfWrapper::_fatal_error( $error_message );
}

my $_crf_server_url = 'http://127.0.0.1:8441/crf';

say STDERR "CRF model runner web service URL: $_crf_server_url";

sub set_webservice_url()
{
    my ( $crf_server_url ) = @_;

    my $uri;
    eval { $uri = URI->new( $crf_server_url )->canonical; };
    if ( $@ )
    {
        _fatal_error( "Invalid CRF model runner web service URI: $crf_server_url" );
    }

    # If someone forgot to explicitly set the port
    my $default_protocol_port = $uri->default_port;    # e.g. 80
    if ( $uri->port == $default_protocol_port and ( $crf_server_url !~ /:$default_protocol_port/ ) )
    {
        warn( "CRF model runner web service URL's port was not set, to I'm setting it to " . DEFAULT_CRF_PORT );
        $uri->port( DEFAULT_CRF_PORT );
    }

    $_crf_server_url = $uri->as_string;
}

#
# Mallet::CrfWrapper "implementation"
#

sub create_model($$$)
{
    my ( $class, $training_data_file, $iterations ) = @_;

    # Clients should use Mallet::CrfWrapper::InlineJava directly
    _fatal_error( "Not implemented in " . __PACKAGE__ );
}

sub run_model_inline_java_data_array($$$)
{
    my ( $class, $model_file_name, $test_data_array ) = @_;

    _validate_model_file_name( $model_file_name );

    my $test_data = join "\n", @{ $test_data_array };

    # If test data is empty
    unless ( $test_data )
    {
        return [];
    }

    my $test_data_encoded;
    eval {
        # Have to encode because HTTP::Request only accepts bytes as POST data
        $test_data_encoded = Encode::encode_utf8( $test_data );
    };
    if ( $@ )
    {
        _fatal_error( "Unable to encode_utf8() data: $test_data" );
    }

    # Make a request
    my $ua = MediaWords::Util::Web::UserAgent;
    $ua->max_size( undef );

    unless ( $_crf_server_url )
    {
        _fatal_error( "Unable to determine CRF model runner web service URL to use." );
    }

    my $request = HTTP::Request->new( POST => $_crf_server_url );
    $request->content_type( 'text/plain; charset=utf8' );
    $request->content( $test_data_encoded );

    my $response = $ua->request( $request );

    my $results_string;
    if ( $response->is_success )
    {
        # OK
        $results_string = $response->decoded_content;
    }
    else
    {
        # Error; determine whether we should be blamed for making a malformed
        # request, or is it an extraction error

        if ( MediaWords::Util::Web::response_error_is_client_side( $response ) )
        {
            # Error was generated by LWP::UserAgent (created by
            # MediaWords::Util::Web::UserAgent); likely we didn't reach server
            # at all (timeout, unresponsive host, etc.)
            _fatal_error( 'LWP error: ' . $response->status_line . ': ' . $response->decoded_content );

        }
        else
        {
            # Error was generated by server

            my $http_status_code = $response->code;

            if ( $http_status_code == HTTP_METHOD_NOT_ALLOWED or $http_status_code == HTTP_BAD_REQUEST )
            {
                # Not POST, empty POST
                _fatal_error( $response->status_line . ': ' . $response->decoded_content );

            }
            elsif ( $http_status_code == HTTP_INTERNAL_SERVER_ERROR )
            {
                # CRF processing error -- die() so that the error gets caught and logged into a database
                die( 'CRF web service was unable to process the download: ' . $response->decoded_content );

            }
            else
            {
                # Shutdown the extractor on unconfigured responses
                _fatal_error( 'Unknown HTTP response: ' . $response->status_line . ': ' . $response->decoded_content );
            }
        }
    }

    unless ( $results_string )
    {
        _fatal_error( "Server returned nothing for POST data: " . $test_data );
    }

    my $results = decode_json( $results_string );

    return $results;
}

sub _validate_model_file_name($)
{
    my $model_file_name = shift;

    my $expected_model_file_name = MediaWords::Util::CrfExtractor::get_path_to_extractor_model();

    unless ( $model_file_name eq $expected_model_file_name )
    {
        my $error_message = <<"EOF";
FIXME: web service has its very own hardcoded model file name, so
$model_file_name parameter in the subroutines of this package are useless
and misleading.

Expected model path (the one that is hardcoded into a Java class): $expected_model_file_name

Actual model path (the one provided to one of the CRF processing subroutines): $model_file_name
EOF

        _fatal_error( $error_message );
    }
}

1;
