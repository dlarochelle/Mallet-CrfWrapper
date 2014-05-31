package Mallet::CrfWrapper;

use 5.006;
use strict;


=head1 NAME

Mallet::CrfWrapper - The great new Mallet::CrfWrapper!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Mallet::CrfWrapper;

    my $foo = Mallet::CrfWrapper->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 function1

#
# Facade to either Inline::Java based or a web service-based CRF model runner
#

use strict;
use warnings;

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


=head1 LICENSE AND COPYRIGHT

Copyright 2014 David Larochelle.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Mallet::CrfWrapper

