package Mallet::CrfWrapper;

use 5.14.0;
use strict;
use warnings;

=head1 NAME

Mallet::CrfWrapper 

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

This module provides a convenient wrapper around Mallet's CRF package.

It can use either Inline::Java or a WebService to interface with Mallet.

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 function1

=cut

#
# Facade to either Inline::Java based or a web service-based CRF model runner
#


# Name of a loaded and active CRF module, either 'Mallet::CrfWrapper::InlineJava' or
# 'Mallet::CrfWrapper::WebService'.
#
# Loading of the module is postponed because Mallet::CrfWrapper::InlineJava compiles
# a Java class and loads it into a JVM in BEGIN{}, which slows down scripts
# that don't have anything to do with extraction
my $_active_crf_module = undef;

my $_webservice_enabled = undef;

my $_webservice_url = undef;

sub use_webservice
{
    my ( $flag ) = @_;

    if ( defined( $flag ) && $flag )
    {
        $_webservice_enabled = 1;
    }
    else
    {
        $_webservice_enabled = 0;
    }
}

sub set_webservice_url
{
    my ( $url ) = @_;

    $_webservice_url = $url;
}

sub _load_and_return_crf_module()
{
    unless ( $_active_crf_module )
    {
        my $module;

        if ( $_webservice_enabled )
        {
            $module = 'Mallet::CrfWrapper::WebService';
        }
        else
        {
            $module = 'Mallet::CrfWrapper::InlineJava';
        }

        eval {
            ( my $file = $module ) =~ s|::|/|g;
            require $file . '.pm';
            $module->import();

            if ( ( $module eq 'Mallet::CrfWrapper::WebService' ) && ( defined( $_webservice_url ) ) )
            {
                $module->set_webservice_url( $_webservice_url );
            }
            1;
        } or do
        {
            my $error = $@;
            _fatal_error( "Unable to load $module: $error" );
        };

        $_active_crf_module = $module;
    }

    return $_active_crf_module;
}

sub create_model($$)
{
    my ( $training_data_file, $iterations ) = @_;

    my $module = _load_and_return_crf_module();

    return $module->create_model( $training_data_file, $iterations );
}

sub run_model_inline_java_data_array($$)
{
    my ( $model_file_name, $test_data_array ) = @_;

    my $module = _load_and_return_crf_module();

    return $module->run_model_inline_java_data_array( $model_file_name, $test_data_array );
}

# Helper
sub _fatal_error($)
{
    # There are errors that cannot be classified as extractor errors (that
    # would get logged into the database). For example, if the whole CRF model
    # runner web service is down, no extractions of any kind can happen anyway,
    # so it's not worthwhile to write a gazillion "extractor error: CRF web
    # service is down" errors to the database.
    #
    # Instead, we go the radical way of killing the whole extractor process. It
    # is more likely that someone will notice that the CRF model runner web
    # service is malfunctioning if the extractor gets shut down.
    #
    # Usual die() wouldn't work here because it is (might be) wrapped into an
    # eval{}.

    my $error_message = shift;

    say STDERR $error_message;
    exit 1;
}


=head1 AUTHOR

David Larochelle, C<< <drlaro at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-mallet-crfwrapper at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Mallet-CrfWrapper>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Mallet::CrfWrapper


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mallet-CrfWrapper>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Mallet-CrfWrapper>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Mallet-CrfWrapper>

=item * Search CPAN

L<http://search.cpan.org/dist/Mallet-CrfWrapper/>

=back


=head1 ACKNOWLEDGEMENTS

Linas Valiukas made numerous performance improvements and added the WebService code.

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Berkman Center for Internet & Society at Harvard University.

This distribution includes JAR files for Mallet which are licensed under the Common Public License and are Copyright UMass Umherst.

=cut

1; # End of Mallet::CrfWrapper

