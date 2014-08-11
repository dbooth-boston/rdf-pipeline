#! /usr/bin/perl -w 
package RDF::Pipeline::ExampleHtmlNode;

# RDF Pipeline Framework -- ExampleHtmlNode

# Copyright 2014 by David Booth
# This software is available as free and open source under
# the Apache 2.0 software license, which may be viewed at
# http://www.apache.org/licenses/LICENSE-2.0.html
# Code home: https://github.com/dbooth-boston/rdf-pipeline/

# This is a simple, minimal example wrapper that is only used to test
# the wrapper mechanism in the RDF Pipeline framework and to
# demonstrate how to write a wrapper.  It is not suitable for any 
# application purposes.

use 5.10.1; 	# It *may* work under lower versions, but has not been tested.
use strict;
use warnings;
use Carp;

require Exporter;
our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use RDF::Pipeline::ExampleHtmlNode ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
);

our $VERSION = '0.01';

#file:RDF-Pipeline/lib/RDF/Pipeline/ExampleHtmlNode.pm
#----------------------

############# ExampleHtmlNodeRegister ##############
sub ExampleHtmlNodeRegister
{
@_ == 1 || die;
my ($nm) = @_;
$nm->{value}->{ExampleHtmlNode} = {};
$nm->{value}->{ExampleHtmlNode}->{fSerializer} = \&ExampleHtmlNodeSerializer;
$nm->{value}->{ExampleHtmlNode}->{fDeserializer} = \&ExampleHtmlNodeDeserializer;
$nm->{value}->{ExampleHtmlNode}->{fUriToNativeName} = \&RDF::Pipeline::UriToPath;
$nm->{value}->{ExampleHtmlNode}->{fRunUpdater} = \&RDF::Pipeline::FileNodeRunUpdater;
$nm->{value}->{ExampleHtmlNode}->{fRunParametersFilter} = \&RDF::Pipeline::FileNodeRunParametersFilter;
$nm->{value}->{ExampleHtmlNode}->{fExists} = \&RDF::Pipeline::FileExists;
$nm->{value}->{ExampleHtmlNode}->{defaultContentType} = "text/html";
}

############# ExampleHtmlNodeSerializer ##############
sub ExampleHtmlNodeSerializer
{
@_ == 4 || die;
my ($serFilename, $deserName, $contentType, $hostRoot) = @_;
$serFilename or die;
$deserName or die;
die if $serFilename eq $deserName;
die if $contentType && $contentType !~ m|html|i;
$hostRoot = $hostRoot;  # Avoid unused var warning
open(my $deserFH, $deserName) || die;
my $all = join("", <$deserFH>);
close($deserFH) || die;
# Write to the serialized file:
open(my $serFH, ">$serFilename") || die;
# Add HTML tags:
print $serFH "<html>\n<body>\n<pre>\n";
print $serFH $all;
print $serFH "</pre>\n</body>\n</html>\n";
close($serFH) || die;
return 1;
}

############# ExampleHtmlNodeDeserializer ##############
sub ExampleHtmlNodeDeserializer
{
@_ == 4 || die;
my ($serFilename, $deserName, $contentType, $hostRoot) = @_;
$serFilename or die;
$deserName or die;
die if $serFilename eq $deserName;
die if $contentType && $contentType !~ m|html|i;
$hostRoot = $hostRoot;  # Avoid unused var warning
open(my $serFH, $serFilename) || confess "ERROR ";
my $all = join("", <$serFH>);
close($serFH) || die;
# Get rid of HTML tags:
($all =~ s/\<html\b[^\>]*\>/ /ig) or die;
$all =~ s/\<[^\>]*\>/ /g;
$all =~ s/\A[\s\n]+//;
$all =~ s/[\s\n]+\Z/\n/;
# Write to the deserialized file:
&RDF::Pipeline::MakeParentDirs($deserName);
open(my $deserFH, ">$deserName") || confess "ERROR: Cannot write to $deserName\n ";
print $deserFH $all;
close($deserFH) || die;
return 1;
}



##### DO NOT DELETE THE FOLLOWING TWO LINES!  #####
1;
__END__

=head1 NAME

RDF::Pipeline::ExampleHtmlNode - Example wrapper for RDF Pipeline Framework

=head1 SYNOPSIS

In Pipeline.pm:

  use RDF::Pipeline::ExampleHtmlNode;

Then in sub RegisterWrappers:

  &RDF::Pipeline::ExampleHtmlNode::ExampleHtmlNodeRegister($nm);

And in ont/ont.n3 add:

  p:ExampleHtmlNode       rdfs:subClassOf p:Node ;
    p:defaultContentType "text/html" .


=head1 DESCRIPTION

This is a minimal wrapper that is only used: (a) for testing the wrapper
mechanism in the RDF Pipeline framework; and (b) as a simple example
of how to write a wrapper.  It "serializes" a plain text file by adding
HTML tags around it, and "deserializes" by removing those HTML tags.

The adding and removing of HTML tags is very stupid.  It is good
enough for simple tests and examples but is not suitable
for any real application.

=head2 EXPORT

None by default.


=head1 SEE ALSO

http://code.google.com/p/rdf-pipeline/wiki/WrapperInterface

=head1 AUTHOR

David Booth <david@dbooth.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2012 David Booth <david@dbooth.org>
See license information at http://code.google.com/p/rdf-pipeline/ 

=cut

