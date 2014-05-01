#! /usr/bin/perl -w 
package RDF::Pipeline::GraphNode;

# RDF Pipeline Framework -- GraphNode
# Copyright 2012 David Booth <david@dbooth.org>
# Code home: http://code.google.com/p/rdf-pipeline/
# See license information at http://code.google.com/p/rdf-pipeline/ 


use 5.10.1; 	# It *may* work under lower versions, but has not been tested.
use strict;
use warnings;
use Carp;
use RDF::Pipeline ':all';
use RDF::Pipeline::Template ':all';

require Exporter;
our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use RDF::Pipeline::GraphNode ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
);

our $VERSION = '0.01';

#file:RDF-Pipeline/lib/RDF/Pipeline/GraphNode.pm
#----------------------

############# GraphNodeRegister ##############
sub GraphNodeRegister
{
@_ == 1 || die;
my ($nm) = @_;
$nm->{value}->{GraphNode} = {};
$nm->{value}->{GraphNode}->{fSerializer} = \&GraphNodeSerializer;
$nm->{value}->{GraphNode}->{fDeserializer} = \&GraphNodeDeserializer;
$nm->{value}->{GraphNode}->{fUriToNativeName} = undef;
$nm->{value}->{GraphNode}->{fRunUpdater} = \&GraphNodeRunUpdater;
$nm->{value}->{GraphNode}->{fRunParametersFilter} = \&RDF::Pipeline::FileNodeRunParametersFilter;
$nm->{value}->{GraphNode}->{fExists} = \&GraphNodeExists;
$nm->{value}->{GraphNode}->{defaultContentType} = "text/turtle";
}

############# GraphNodeRunUpdater ##############
# Run the updater.
# If there is no updater (i.e., static state) then we must generate
# an LM from the state.
sub GraphNodeRunUpdater
{
@_ == 9 || die;
my ($nm, $thisUri, $updater, $state, $thisInputs, $thisParameters, 
	$oldThisLM, $callerUri, $callerLM) = @_;
# Avoid unused var warning:
($nm, $thisUri, $updater, $state, $thisInputs, $thisParameters, 
	$oldThisLM, $callerUri, $callerLM) = @_;
($nm, $thisUri, $updater, $state, $thisInputs, $thisParameters, 
	$oldThisLM, $callerUri, $callerLM) = @_;
&RDF::Pipeline::Warn("GraphNodeRunUpdater(nm, $thisUri, $updater, $state, ...) called.\n", $RDF::Pipeline::DEBUG_DETAILS);
# warn "GraphNodeRunUpdater(nm, $thisUri, $updater, $state, ...) called.\n";
$updater = &RDF::Pipeline::NodeAbsPath($updater) if $updater;
#### TODO: Is this next line correct? MTime returns a file mod time,
#### but $state isn't a file if $thisUri is a GraphNode.
return &TimeToLM(&MTime($state)) if !$updater;
# TODO: Move this warning to when the metadata is loaded?
if (!-e $updater) {
        die "ERROR: $thisUri updater does not exist: $updater";
        }
# @@@@@
#### TODO QUERY:
my $thisVHash = $nm->{value}->{$thisUri} or die;
my $parametersFile = $thisVHash->{parametersFile} or die;
my ($lm, $latestQuery, %requesterQueries) = 
	&RDF::Pipeline::LookupLMs($RDF::Pipeline::FILE, $parametersFile);
$lm = $lm;				# Avoid unused var warning
my $qLatestQuery = quotemeta($latestQuery);
my $exportqs = "export QUERY_STRING=$qLatestQuery";
# my $qss = quotemeta(&BuildQueryString(%requesterQueries));
my $qss = quotemeta(join(" ", sort values %requesterQueries));
my $exportqss = "export QUERY_STRINGS=$qss";
####
my $stderr = $nm->{value}->{$thisUri}->{stderr};
# Make sure parent dirs exist for $stderr:
&RDF::Pipeline::MakeParentDirs($stderr);
my $template = &RDF::Pipeline::ReadFile($updater);
#### TODO: Also pass $QUERY_STRINGS (plural) to &ProcessTemplate?
#### But we don't yet have convenient ways to use it.
my $sparqlUpdate = &ProcessTemplate($template, $thisInputs, [ $state ],
                       $latestQuery, $thisUri);
my $tmp = "/tmp/GraphNodeUpdater-$$.ru";
&RDF::Pipeline::Warn("GraphNodeRunUpdater sparqlUpdate: \n[[\n$sparqlUpdate\n]]\n", $RDF::Pipeline::DEBUG_DETAILS);
# my $debugDetails = $RDF::Pipeline::DEBUG_DETAILS;
# die "debugDetails: $debugDetails ";
&RDF::Pipeline::WriteFile($tmp, $sparqlUpdate);
# @@@@
# Ensure no unsafe chars before invoking $cmd:
my $qThisUri = quotemeta($thisUri);
my $qState = quotemeta($state);
my $qUpdater = quotemeta($updater);
my $qStderr = quotemeta($stderr);
my $useStdout = 0;
# my $ins = join(" ", map {"-i " . quotemeta($_)} @{$thisInputs});
# my $cmd = "( cd '$nodeBasePath' ; export THIS_URI=$qThisUri ; $exportqs ; $exportqss ; $qUpdater $ins -o $qState > $qStderr 2>&1 )";
# /usr/bin/curl  -s --data-urlencode  'update=LOAD <file:///home/dbooth/rdf-pipeline/trunk/RDF-Pipeline/t/tests/0035_GraphNode_Basic/bill-presidents.ttl> INTO GRAPH <http://example/in>' 'http://localhost:28080/openrdf-workbench/repositories/owlimlite/update'
my $thisType = $thisVHash->{nodeType} || "";
my $nmh = $nm->{hash};
# warn "GraphNodeRunUpdater: thisType: $thisType baseUri: $RDF::Pipeline::baseUri\n";
my $thisHostRoot = $nmh->{$thisType}->{hostRoot}->{$RDF::Pipeline::baseUri};
if (!$thisHostRoot) {
  &RDF::Pipeline::Warn("GraphNodeRunUpdater: ERROR: hostRoot not set for node $thisUri type $thisType\n");
  return "";
  }
#### TODO: Make this non-Sesame specific:
my $cmd = "/usr/bin/curl  -s -S --data-urlencode  'update\@$tmp' '${thisHostRoot}/update'";
&RDF::Pipeline::Warn("GraphNodeRunUpdater cmd: $cmd\n", $RDF::Pipeline::DEBUG_DETAILS);
my $result = (system($cmd) >> 8);
my $saveError = $?;
&RDF::Pipeline::Warn("GraphNodeRunUpdater: Updater returned " . ($result ? "error code:" : "success:") . " $result.\n", $RDF::Pipeline::DEBUG_DETAILS);
if (-s $stderr) {
	&RDF::Pipeline::Warn("GraphNodeRunUpdater: Updater stderr" . ($useStdout ? "" : " and stdout") . ":\n[[\n", $RDF::Pipeline::DEBUG_DETAILS);
	&RDF::Pipeline::Warn(&RDF::Pipeline::ReadFile("<$stderr"), $RDF::Pipeline::DEBUG_DETAILS);
	&RDF::Pipeline::Warn("]]\n", $RDF::Pipeline::DEBUG_DETAILS);
	}
unlink $tmp;
# unlink $stderr;
if ($result) {
	&RDF::Pipeline::Warn("GraphNodeRunUpdater: UPDATER ERROR: $saveError\n");
	return "";
	}
my $newLM = &RDF::Pipeline::GenerateNewLM();
&RDF::Pipeline::Warn("GraphNodeRunUpdater returning newLM: $newLM\n", $RDF::Pipeline::DEBUG_DETAILS);
return $newLM;
}

############# GraphNodeExists ##############
sub GraphNodeExists
{
@_ == 2 || die;
my ($deserName, $hostRoot) = @_;
($deserName, $hostRoot) = ($deserName, $hostRoot); # Avoid unused var warning
# SPARQL does not have a way to determine if a graph exists, because
# empty graphs may be silently deleted.
return 1;
}

############# GraphNodeSerializer ##############
sub GraphNodeSerializer
{
@_ == 4 || die;
my ($serFilename, $deserName, $contentType, $hostRoot) = @_;
$serFilename or die;
$deserName or die;
# die if $serFilename eq $deserName;
$contentType ||= "text/turtle";
$hostRoot || die "GraphNodeSerializer: ERROR: \$hostRoot not specified\n";
### TODO: Make this non-Sesame specific:
$hostRoot =~ s|/openrdf-workbench/|/openrdf-sesame/|;
$hostRoot =~ m|/openrdf-sesame/| or confess "[ERROR] GraphNode hostRoot does not match sesame pattern: $hostRoot ";
# $hostRoot = "http://localhost:28080/openrdf-sesame/repositories/owlimlite";
# http://localhost:28080/openrdf-sesame/repositories/owlimlite/rdf-graphs/service?graph=http://example/in
my $curlUrl =  "${hostRoot}/rdf-graphs/service?graph=$deserName";
### TODO: Make this safer by using quotemeta for everything in the command:
# my $qCurlUrl = quotemeta($curlUrl);
# my $qSerFilename = quotemeta($serFilename);
### TODO: Make this non-Sesame specific.  Might need to pass $nm to wrapper
### functions to achieve this.  Maybe use property hostRootTemplate:
### '${hostRoot}/rdf-graphs/service?graph=$deserName';
# curl -s -H 'Accept: text/turtle' -X GET 'http://localhost:28080/openrdf-sesame/repositories/owlimlite/rdf-graphs/service?graph=http://example/in'
my $curlCmd = "/usr/bin/curl -s -H 'Accept: text/turtle' -X GET '$curlUrl' -o '$serFilename'";
# warn "GraphNodeSerializer curlCmd: $curlCmd\n";
&RDF::Pipeline::Warn("GraphNodeSerializer curlCmd: $curlCmd\n", $RDF::Pipeline::DEBUG_DETAILS);
my $success = !system($curlCmd);
&RDF::Pipeline::Warn("GraphNodeSerializer($serFilename, $deserName, $contentType, $hostRoot) FAILED\n", $RDF::Pipeline::DEBUG_OFF) if !$success;
if ($RDF::Pipeline::debug >= $RDF::Pipeline::DEBUG_DETAILS) {
	my $t = `head -n 20 $serFilename`;
	&RDF::Pipeline::Warn("GraphNodeSerializer produced  $serFilename :\n[[\n$t\n. . . .\n]]\n", $RDF::Pipeline::DEBUG_DETAILS);
	}
return $success;
}

############# GraphNodeDeserializer ##############
sub GraphNodeDeserializer
{
@_ == 4 || die;
my ($serFilename, $deserName, $contentType, $hostRoot) = @_;
$serFilename or die;
$deserName or die;
# die if $serFilename eq $deserName;
$contentType ||= "text/turtle";
$hostRoot || die "GraphNodeSerializer: ERROR: \$hostRoot not specified\n";
# $hostRoot = "http://localhost:28080/openrdf-sesame/repositories/owlimlite";
# http://localhost:28080/openrdf-workbench/repositories/owlimlite/update
my $curlUrl = "${hostRoot}/update";
$curlUrl =~ s|/openrdf-sesame/|/openrdf-workbench/|;
### TODO: Make this safer by using quotemeta for everything in the command:
### TODO: Make this non-Sesame specific.  Might need to pass $nm to wrapper
### functions to achieve this.  
# curl  -s --data-urlencode  'update=CLEAR SILENT GRAPH <$deserName> ; LOAD <file://$serFilename> INTO GRAPH <$deserName>' 'http://localhost:28080/openrdf-workbench/repositories/owlimlite/update'
#### TODO: Awful hack get OWLIM reader to recognize Turtle via file extension:
my $tmpDir = $ENV{TEMPDIR} || "/tmp";
$tmpDir =~ s|\/$|| if length($tmpDir) > 1;
my $tmp = "$tmpDir/GraphNodeDeserializer-$$.ttl";
my $curlCmd = "/bin/cp $serFilename $tmp ; /usr/bin/curl  -s -S --data-urlencode  'update=CLEAR SILENT GRAPH <$deserName> ; LOAD <file://$tmp> INTO GRAPH <$deserName>' '$curlUrl'";
&RDF::Pipeline::Warn("GraphNodeDeserializer curlCmd: $curlCmd\n", $RDF::Pipeline::DEBUG_DETAILS);
my $success = !system($curlCmd);
&RDF::Pipeline::Warn("GraphNodeDeserializer($serFilename, $deserName, $contentType, $hostRoot) FAILED\n", $RDF::Pipeline::DEBUG_OFF) if !$success;
if ($RDF::Pipeline::debug >= $RDF::Pipeline::DEBUG_DETAILS) {
	my $t = `head -n 20 $tmp`;
	&RDF::Pipeline::Warn("GraphNodeDeserializer loaded  $serFilename / $tmp :\n[[\n$t\n. . . .\n]]\n", $RDF::Pipeline::DEBUG_DETAILS);
	}
unlink $tmp;
return $success;
}

##### DO NOT DELETE THE FOLLOWING TWO LINES!  #####
1;
__END__

=head1 NAME

RDF::Pipeline::GraphNode - RDF named graph wrapper for RDF Pipeline Framework

=head1 SYNOPSIS

In Pipeline.pm:

  use RDF::Pipeline::GraphNode;

Then in sub RegisterWrappers:

  &RDF::Pipeline::GraphNode::GraphNodeRegister($nm);

In ont/ont.n3 add:

  p:GraphNode       rdfs:subClassOf p:Node ;
    p:defaultContentType "text/turtle" .

And in node/pipeline.ttl it can be used as:

  @prefix : <http://localhost/node/> .

  :foo a p:GraphNode ;
    p:inputs ( . . . ) .

  # Specify SPARQL server URI for p:GraphNodes at http://localhost :
  p:GraphNode p:hostRoot
    ( "http://localhost" "http://localhost:28080/openrdf-workbench/repositories/owlimlite/" ) .


=head1 DESCRIPTION

This is an initial implementation of a wrapper for representing
an RDF named graph that is stored within a SPARQL server.
It is currently Sesame-specific, but the plan is to make it
more generic in a future version.

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

