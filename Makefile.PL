use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Mallet::CrfWrapper',
    AUTHOR           => q{David Larochelle <drlaro@cpan.org>},
    VERSION_FROM     => 'lib/Mallet/CrfWrapper.pm',
    ABSTRACT_FROM    => 'lib/Mallet/CrfWrapper.pm',
    LICENSE          => 'Artistic_2_0',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'Inline::Java' => 0.53,
	'HTTP::Request' => 5.814,
	'HTTP::Status' => 0,
        #'ABC'              => 1.6,
        #'Foo::Bar::Module' => 5.0401,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Mallet-CrfWrapper-*' },
);
