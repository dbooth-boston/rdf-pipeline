#! /usr/bin/perl -w

use 5.010001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'RDF::Pipeline',
    VERSION_FROM      => 'lib/RDF/Pipeline.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/RDF/Pipeline.pm', # retrieve abstract from module
       AUTHOR         => 'David Booth <david@dbooth.org>') : ()),
);
