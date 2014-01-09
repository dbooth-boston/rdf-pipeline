#! /usr/bin/perl -w 

# Test wrapper functions from the command line.

# Copyright 2012 David Booth <david@dbooth.org>
# Code home: http://code.google.com/p/rdf-pipeline/
# See license information at http://code.google.com/p/rdf-pipeline/ 

use 5.10.1; 	# It *may* work under lower versions, but has not been tested.
use strict;
use warnings;
use Carp;
use Cwd;

use RDF::Pipeline::GraphNode;

my $inSerFilenameTail = "bill-presidents.ttl";
my $outSerFilenameTail = "bill-presidents-out.ttl";
my $inSerFilename = getcwd() . "/" . $inSerFilenameTail;
my $outSerFilename = getcwd() . "/" . $outSerFilenameTail;
my $deserName = "http://example/in";
my $contentType = "text/turtle";
my $hostRoot = "http://localhost:28080/openrdf-workbench/repositories/owlimlite/";
-e $inSerFilename or die "ERROR: File not found: $inSerFilename\n";
unlink($outSerFilename) if -e $outSerFilename;
&RDF::Pipeline::GraphNode::GraphNodeDeserializer($inSerFilename, $deserName, $contentType, $hostRoot) or die;

my $nm = undef;
my $thisUri = "http://example/mynode";
# my $updater = "
# @@@@
# my $newLM = &RDF::Pipeline::GraphNode::GraphNodeRunUpdater($nm, $thisUri, $updater, $state, $thisInputs, $thisParameters, $oldThisLM, $callerUri, $callerLM);

&RDF::Pipeline::GraphNode::GraphNodeSerializer($outSerFilename, $deserName, $contentType, $hostRoot) or die;
exit 0;

# $nm->{value}->{GraphNode}->{fSerializer} = \&GraphNodeSerializer;
# $nm->{value}->{GraphNode}->{fDeserializer} = \&GraphNodeDeserializer;
# $nm->{value}->{GraphNode}->{fUriToNativeName} = \&RDF::Pipeline::UriToPath;
# $nm->{value}->{GraphNode}->{fRunUpdater} = \&RDF::Pipeline::FileNodeRunUpdater;
# $nm->{value}->{GraphNode}->{fRunParametersFilter} = \&RDF::Pipeline::FileNodeRunParametersFilter;
# $nm->{value}->{GraphNode}->{fExists} = \&RDF::Pipeline::FileExists;
# $nm->{value}->{GraphNode}->{defaultContentType} = "text/html";

