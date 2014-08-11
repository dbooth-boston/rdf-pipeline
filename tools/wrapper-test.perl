#! /usr/bin/perl -w 

# Copyright 2014 by David Booth
# This software is available as free and open source under
# the Apache 2.0 software license, which may be viewed at
# http://www.apache.org/licenses/LICENSE-2.0.html
# Code home: https://github.com/dbooth-boston/rdf-pipeline/

# Test wrapper functions from the command line.
# This script may be customized for use in testing a new
# wrapper.  It doesn't do much, but it was used in initially testing
# GraphNode, though only a part of the functionality.

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

