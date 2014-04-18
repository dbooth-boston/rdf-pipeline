#! /usr/bin/perl -w 
package RDF::Pipeline;

# RDF Pipeline Framework
# Copyright 2011 & 2012 David Booth <david@dbooth.org>
# Code home: http://code.google.com/p/rdf-pipeline/
# See license information at http://code.google.com/p/rdf-pipeline/ 

# Command line test (cannot currently be used, due to bug #9 fix):
#  MyApache2/Chain.pm --test --debug http://localhost/hello
# Maybe command line test could be made to work again using:
#   https://metacpan.org/module/Test::Mock::Apache2
#
# To restart apache (under root):
#  apache2ctl stop ; sleep 5 ; truncate -s 0 /var/log/apache2/error.log ; apache2ctl start

use 5.10.1; 	# It has not been tested on other versions.
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);

# Items to export into caller's namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use RDF::Pipeline ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	FilterArgs
	ForeignSendHttpRequest
	DeserializeToLocalCache
	HandleHttpEvent
	FreshenSerState
	UpdateQueries
	KeySubset
	SameKeys
	FreshenState
	Notify
	RequestLatestDependsOns
	LoadNodeMetadata
	PresetGenericDefaults
	MakeValuesAbsoluteUris 
	FindUpdater
	LazyUpdatePolicy
	LeafClasses
	BuildQueryString
	ParseQueryString
	CheatLoadN3
	WriteFile
	ReadFile
	NameToLmFile
	SaveLMs
	LookupLMs
	SaveLMHeaders
	LookupLMHeaders
	FileExists
	RegisterWrappers
	FileNodeRegister
	FileNodeRunParametersFilter
	LatestRunParametersFilter 
	FileNodeRunUpdater
	GenerateNewLM
	MTimeAndInode
	MTime
	QuickName
	HashName
	HashTemplateName
	NodeAbsUri
	AbsUri
	UriToPath
	NodeAbsPath
	AbsPath
	PathToUri
	PrintLog
	Warn
	MakeParentDirs
	IsSameServer
	IsSameType
	FormatTime
	FormatCounter
	TimeToLM
	LMToHeaders
	HeadersToLM
	PrintNodeMetadata

	$DEBUG_DETAILS

	$pipelinePrefix
	$baseUri
	$baseUriPattern
	$basePath
	$basePathPattern
	$nodeBaseUri
	$nodeBaseUriPattern
	$nodeBasePath
	$nodeBasePathPattern
	$lmCounterFile
	$rdfsPrefix
	$subClassOf
	$configFile
	$ontFile
	$internalsFile
	$URI
	$FILE

	) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
);

our $VERSION = '0.01';

#file:RDF-Pipeline/lib/RDF/Pipeline.pm
#----------------------
# Apache2 uses multiple threads and a pool of PerlInterpreters.
# Code below that is outside of any function will be executed once
# for each PerlInterpreter instance when it starts.  Since existing
# PerlInterpreter instances will be used first, a new instance will 
# only be started when all existing instances are busy.  Also, in
# spite of being threaded, variables are separate between 
# instances -- mod_perl does this somehow -- so one instance will not see
# changes made to another instance's variables unless something
# special is done to make them shared.  (Maybe threads::shared?
# Or Apache::Session::File?)  This means that HTTP response headers
# cannot be cached in memory (without doing something special),
# because they won't be visible across thread instances.

# See http://perl.apache.org/docs/2.0/user/intro/start_fast.html
use Carp;
# use diagnostics;
use Apache2::RequestRec (); # for $r->content_type
use Apache2::SubRequest (); # for $r->internal_redirect
use Apache2::RequestIO ();
# use Apache2::Const -compile => qw(OK SERVER_ERROR NOT_FOUND);
use Apache2::Const -compile => qw(:common REDIRECT HTTP_NO_CONTENT DIR_MAGIC_TYPE HTTP_NOT_MODIFIED);
use Apache2::Response ();
use APR::Finfo ();
use APR::Const -compile => qw(FINFO_NORM);
use Apache2::RequestUtil ();
use Apache2::Const -compile => qw( HTTP_METHOD_NOT_ALLOWED );
use Fcntl qw(LOCK_EX O_RDWR O_CREAT);

use HTTP::Date;
use APR::Table ();
use LWP::UserAgent;
use HTTP::Status;
use Apache2::URI ();
use URI::Escape;
use Time::HiRes ();
use File::Path qw(make_path remove_tree);
use WWW::Mechanize;
use Digest::MD4 qw(md4_base64);

################## Node Types ###################
# use lib qw( /home/dbooth/rdf-pipeline/trunk/RDF-Pipeline/lib );
use RDF::Pipeline::ExampleHtmlNode;
use RDF::Pipeline::GraphNode;

##################  Debugging and testing ##################
# $debug verbosity:
our $DEBUG_OFF = 0;	# No debug output.  Warnings/errors only.
our $DEBUG_NODE_UPDATES = 1; 	# Show nodes updated.
our $DEBUG_PARAM_UPDATES = 2; 	# Also show parameters updated.
our $DEBUG_CACHES = 3; 	# Also show caches updated.
our $DEBUG_CHANGES = 4; 	# Also show them unchanged.  This verbosity is normally used for regression testing.
our $DEBUG_REQUESTS = 5;	# Also show requests.
our $DEBUG_DETAILS = 6;	# Show requests plus more detail.

# $debug level is set using a PerlSetEnv directive in 
# the apache2 config file:
our $debug = $ENV{RDF_PIPELINE_DEBUG};
$debug = $DEBUG_CHANGES if !defined($debug) or $debug !~ m/\S/;
# $debug = $DEBUG_DETAILS;
my $rawDebug = $debug;
# Allows symbolic $debug value:
$debug = eval $debug if defined($debug) && $debug =~ m/^\$\w+$/;  
die "ERROR: debug not defined: $rawDebug " if !defined($debug);

our $debugStackDepth = 0;	# Used for indenting debug messages.

our $test;

##################  Constants for this server  ##################
our $pipelinePrefix = "http://purl.org/pipeline/ont#";	# Pipeline ont prefix
$ENV{DOCUMENT_ROOT} ||= "/home/dbooth/rdf-pipeline/Private/www";	# Set if not set
### TODO: Set $baseUri properly.  Needs port?
$ENV{SERVER_NAME} ||= "localhost";
# $baseUri is the URI prefix that corresponds directly to DOCUMENT_ROOT.
our $baseUri = "http://$ENV{SERVER_NAME}";  # TODO: Should become "scope"?
our $baseUriPattern = quotemeta($baseUri);
our $basePath = $ENV{DOCUMENT_ROOT};	# Synonym, for convenience
our $basePathPattern = quotemeta($basePath);
our $nodeBaseUri = "$baseUri/node";	# Base for nodes
our $nodeBaseUriPattern = quotemeta($nodeBaseUri);
our $nodeBasePath = "$basePath/node";
our $nodeBasePathPattern = quotemeta($nodeBasePath);
our $lmCounterFile = "$basePath/lm/lmCounter.txt";
our $rdfsPrefix = "http://www.w3.org/2000/01/rdf-schema#";
# our $subClassOf = $rdfsPrefix . "subClassOf";
our $subClassOf = "rdfs:subClassOf";

our $configFile = "$nodeBasePath/pipeline.ttl";
our $ontFile = "$basePath/ont/ont.n3";
our $internalsFile = "$basePath/ont/internals.n3";
our $tmpDir = "$basePath/tmp";

#### $nameType constants used by SaveLMs/LookupLMs:
#### TODO: Change to "use Const".
our $URI = 'URI';
our $FILE = 'FILE';

our @systemArgs = qw(debug debugStackDepth callerUri callerLM method);

################### Runtime data ####################

our $configLastModified = 0;
our $ontLastModified = 0;
our $internalsLastModified = 0;
our $configLastInode = 0;
our $ontLastInode = 0;
our $internalsLastInode = 0;

our $logFile = "/tmp/rdf-pipeline-log.txt";
# unlink $logFile || die;

my %config = ();		# Maps: "?s ?p" --> "v1 v2 ... vn"
my %configValues = ();		# Maps: "?s ?p" --> {v1 => 1, v2 => 1, ...}

# Node Metadata hash maps for mapping from subject
# to predicate to single value ($nmv), list ($nml) or hashmap ($nmh).  
#  For single-valued predicates:
#    my $nmv = $nm->{value};	
#    my $value = $nmv->{$subject}->{$predicate};
#  For list-valued predicates:
#    my $nml = $nm->{list};	
#    my $listRef = $nml->{$subject}->{$predicate};
#    my @list = @{$listRef};
#  For hash-valued predicates:
#    my $nmh = $nm->{hash};	
#    my $hashRef = $nmh->{$subject}->{$predicate};
#    my $value = $hashRef->{$key};
#  For multi-valued predicates:
#    my $nmm = $nm->{multi};	
#    my $hashRef = $nmm->{$subject}->{$predicate};
#      For list of unique values (for non-unique use {list} instead):
#    my @values = keys %{$hashRef};
#      To see if a particular value exists (each $value is mapped to 1):
#    if ($hashRef->{$value}) ...
my $nm;

&Warn("********** NEW APACHE THREAD INSTANCE **********\n", $DEBUG_DETAILS);
my $hasHiResTime = &Time::HiRes::d_hires_stat()>0;
$hasHiResTime || die;

use Getopt::Long;

&GetOptions("test" => \$test,
	"debug" => \$debug,
	);
&Warn("ARGV: @ARGV\n", $DEBUG_DETAILS) if $test;

my $testUri = shift @ARGV || "http://localhost/chain";
my $testArgs = "";
if ($testUri =~ m/\A([^\?]*)\?/) {
	$testUri = $1;
	$testArgs = $';
	}
if ($test)
	{
	die "COMMAND-LINE TESTING IS NO LONGER IMPLEMENTED!\n";
	# Invoked from the command line, instead of through Apache.
	# Fake a RequestReq object:
	my $r = &MakeFakeRequestReq();
	$r->content_type('text/plain');
	$r->args($testArgs || "");
	$r->set_content_length(0);
	$r->set_content_length(time);
	$r->method("GET");
	$r->header_only(0);
	$r->meets_conditions(1);
	$r->construct_url($testUri); 
	$testUri =~ m|\Ahttp(s?)\:\/\/[^\/]+\/| or die;
	my $path = "/" . $';
	$r->uri($path);
	my $code = &handler($r);
	&Warn("\nHandler returned code: $code\n", $DEBUG_DETAILS);
	exit 0;
	}

#######################################################################
###################### Functions start here ###########################
#######################################################################

##################### handler #######################
# handler will be called by apache2 to handle any request that has
# been specified in /etc/apache2/sites-enabled/000-default .
sub handler
{
my $r = shift || die;
# construct_url omits the query params
my $thisUri = $r->construct_url(); 
my $args = $r->args() || "";
my %args = &ParseQueryString($args);
$debug = $args{debug} if exists($args{debug});
# Allows symbolic $debug value:
$debug = eval $debug if defined($debug) && $debug =~ m/^\$\w+$/;  
$debugStackDepth = $args{debugStackDepth} || 0;
# warn("="x30 . " handler " . "="x30 . "\n");
&Warn("="x30 . " handler " . "="x30 . "\n", $DEBUG_DETAILS);
&Warn("" . `date`, $DEBUG_DETAILS);
&Warn("SERVER_NAME: $ENV{SERVER_NAME}\n", $DEBUG_DETAILS);
&Warn("DOCUMENT_ROOT: $ENV{DOCUMENT_ROOT}\n", $DEBUG_DETAILS);
my @args = %args;
my $nArgs = scalar(@args);
&Warn("Query string (elements $nArgs): $args\n", $DEBUG_DETAILS);
# &Warn("-"x20 . "handler" . "-"x20 . "\n", $DEBUG_DETAILS);
my $ret = &RealHandler($r, $thisUri, %args);
&Warn("RealHandler returned: $ret\n", $DEBUG_DETAILS);
&Warn("="x60 . "\n", $DEBUG_DETAILS);
return $ret;
}

##################### FilterArgs ######################
# Remove internal args from query parameter args.
sub FilterArgs
{
my ($pargs, @toRemove) = @_;
my %toRemove = map {($_, 1)} @toRemove;
my %result = map {($_, $pargs->{$_})} grep {!$toRemove{$_}} keys %{$pargs};
return(%result);
}

##################### RealHandler #######################
sub RealHandler 
{
my $r = shift || die;
my $thisUri = shift || die;
my %args = @_;
# $debug = ($r && $r->uri =~ m/c\Z/);
# $r->content_type('text/plain') if $debug && !$test;
&Warn("RealHandler: $thisUri " . `date`, $DEBUG_DETAILS);
if (0 && $debug) {
	&Warn("Environment variables:\n", $DEBUG_DETAILS);
	foreach my $k (sort keys %ENV) {
		&Warn("  $k = " . $ENV{$k} . "\n", $DEBUG_DETAILS);
		}
	&Warn("\n", $DEBUG_DETAILS);
	}

my $args = $r->args() || "";
&Warn("Query string args unparsed: $args\n", $DEBUG_DETAILS);
&Warn("Query string args parsed:\n", $DEBUG_DETAILS);
foreach my $k (sort keys %args) {
	my $dk = defined($k) ? $k : "(undef)";
	my $v = $args{$k};
	my $dv = defined($v) ? $v : "(undef)";
	&Warn("  $dk=$dv\n", $DEBUG_DETAILS);
	}

# Reload config file?
my ($cmtime, $cinode) = &MTimeAndInode($configFile);
my ($omtime, $oinode) = &MTimeAndInode($ontFile);
my ($imtime, $iinode) = &MTimeAndInode($internalsFile);
$cmtime || die "ERROR: File not found: $configFile\n";
$omtime || die "ERROR: File not found: $ontFile\n";
$imtime || die "ERROR: File not found: $internalsFile\n";
if ($configLastModified != $cmtime
		|| $ontLastModified != $omtime
		|| $internalsLastModified != $imtime
		|| $configLastInode != $cinode
		|| $ontLastInode != $oinode
		|| $internalsLastInode != $iinode) {
	# Initialize node metadata:
	$nm = {"value"=>{}, "list"=>{}, "hash"=>{}, "multi"=>{}};
	&RegisterWrappers($nm);
	&Warn("--------- NodeMetadata after RegisterWrappers -------\n", $DEBUG_DETAILS); 
	&PrintNodeMetadata($nm) if $debug;
	# Reload config file.
	&Warn("Reloading config file: $configFile\n", $DEBUG_DETAILS);
	$configLastModified = $cmtime;
	$ontLastModified = $omtime;
	$internalsLastModified = $imtime;
	$configLastInode = $cinode;
	$ontLastInode = $oinode;
	$internalsLastInode = $iinode;
	if (0) {
		%config = &CheatLoadN3($ontFile, $configFile);
		%configValues = map { 
			my $hr; 
			map { $hr->{$_}=1; } split(/\s+/, ($config{$_}||"")); 
			($_, $hr)
			} keys %config;
		# &Warn("configValues:\n", $DEBUG_DETAILS);
		foreach my $sp (sort keys %configValues) {
			last if !$debug;
			my $hr = $configValues{$sp};
			foreach my $v (sort keys %{$hr}) {
				# &Warn("  $sp $v\n", $DEBUG_DETAILS);
				}
			}
		}
	&LoadNodeMetadata($nm, $ontFile, $configFile);
	&PrintNodeMetadata($nm) if $debug;

	# &Warn("Got here!\n", $DEBUG_DETAILS); 
	# return Apache2::Const::OK;
	# %config || return Apache2::Const::SERVER_ERROR;
	}

my $subtype = $nm->{value}->{$thisUri}->{nodeType} || "";
&Warn("NOTICE: $thisUri is not a Node.\n", $DEBUG_DETAILS) if !$subtype;
&Warn("thisUri: $thisUri subtype: $subtype\n", $DEBUG_DETAILS);
# Allow non-node files in the www/node/ dir to be served normally:
return Apache2::Const::DECLINED if !$subtype;
# return Apache2::Const::NOT_FOUND if !$subtype;
return &HandleHttpEvent($nm, $r, $thisUri, %args);
}

################### ForeignSendHttpRequest ##################
# Send a remote GET, GRAB or HEAD to $depUri if $depLM is newer than 
# the stored LM of $thisUri's local serCache LM for $depLM.
# The reason for checking $depLM here instead of checking it in
# &RequestLatestDependsOns(...) is because the check requires a call to
# &LookupLMHeaders($inSerCache), which needs to be done here anyway
# in order to look up the old LM headers.
# Also remember that $depUri is not necessarily a node: it may be 
# an arbitrary URI source.
# We cannot count on LMs to be monotonic, because they could be
# checksums or such.
sub ForeignSendHttpRequest
{
@_ == 6 or die;
my ($nm, $method, $thisUri, $depUri, $depLM, $depQuery) = @_;
&Warn("ForeignSendHttpRequest(nm, $method, $thisUri, $depUri, $depLM, $depQuery) called\n", $DEBUG_DETAILS);
# Send conditional GET, GRAB or HEAD to depUri with depUri*/serCacheLM
# my $ua = LWP::UserAgent->new;
my $ua = WWW::Mechanize->new();
$ua->agent("$0/0.01 " . $ua->agent);
my $requestUri = $depUri;
my $httpMethod = $method;
#### TODO QUERY: include $depQuery:
my $queryParams = "";
$queryParams .= "\&$depQuery" if $depQuery;
####
if ($method eq "GRAB") {
	$httpMethod = "GET";
	$queryParams .= "&method=$method";
	}
elsif ($method eq "NOTIFY") {
	$httpMethod = "HEAD";
	$queryParams .= "&method=$method";
	}
# Set If-Modified-Since and If-None-Match headers in request, if available.
my $inSerCache = $nm->{hash}->{$thisUri}->{dependsOnSerCache}->{$depUri} || die;
my ($oldLM, $oldLMHeader, $oldETagHeader) = &LookupLMHeaders($inSerCache);
$oldLM ||= "";
$oldLMHeader ||= "";
$oldETagHeader ||= "";
if ($depLM && $oldLM && $oldLM eq $depLM) {
	return $oldLM;
	}
# This is only for prettier debugging output:
$queryParams .= "&debugStackDepth=" . ($debugStackDepth + &CallStackDepth())
	if $debug && $nm->{value}->{$depUri}->{nodeType}
		&& &IsSameServer($baseUri, $depUri);
$requestUri =~ s/\#.*//;  # Strip any frag ID
$queryParams =~ s/\A\&/\?/ if $queryParams && $requestUri !~ m/\?/;
$requestUri .= $queryParams;
&Warn("ForeignSendHttpRequest: Setting req L-MH: $oldLMHeader If-N-M: $oldETagHeader\n", $DEBUG_REQUESTS);
my $req = HTTP::Request->new($httpMethod => $requestUri);
$req || die;
$req->header('If-Modified-Since' => $oldLMHeader) if $oldLMHeader;
$req->header('If-None-Match' => $oldETagHeader) if $oldETagHeader;
my $isConditional = $req->header('If-Modified-Since') ? "CONDITIONAL" : "Unconditional";
my $reqString = $req->as_string;
&Warn("ForeignSendHttpRequest: $isConditional $method from $thisUri to $depUri\n", $DEBUG_REQUESTS);
&Warn("... with L-MH: $oldLMHeader ETagH: $oldETagHeader\n", $DEBUG_DETAILS);
&PrintLog("[[\n$reqString\n]]\n");
############# Sending the HTTP request ##############
# TODO: http://tinyurl.com/cbxgu4y says:
#   If you want to get a large result it is better to write to a file directly:
#   my $res = $ua->request($req,'file_name.txt');
my $res = $ua->request($req) or die;
my $code = $res->code;
&Warn("Code: $code\n", $DEBUG_DETAILS);
$code == RC_NOT_MODIFIED || $code == RC_OK or die "ERROR: Unexpected HTTP response code $code ";
my $newLMHeader = $res->header('Last-Modified') || "";
my $newETagHeader = $res->header('ETag') || "";
if ($code == RC_NOT_MODIFIED) {
	# Apache does not seem to send the Last-Modified header on 304.
	$newLMHeader ||= $oldLMHeader;
	$newETagHeader ||= $oldETagHeader;
	}
&Warn("ForeignSendHttpRequest: $isConditional $method from $thisUri to $depUri returned $code\n", $DEBUG_DETAILS);
&Warn("... with newL-MH: $newLMHeader newETagH: $newETagHeader\n", $DEBUG_DETAILS);
my $newLM = &HeadersToLM($newLMHeader, $newETagHeader);
&Warn("... with newLMHeader: $newLMHeader\n", $DEBUG_DETAILS);
&Warn("... with newETagHeader: $newETagHeader\n", $DEBUG_DETAILS);
&Warn("... with newLM: $newLM\n", $DEBUG_DETAILS);
if ($code == RC_OK && $newLM && $newLM ne $oldLM) {
	### Allow non-monotonic LM (because they could be checksums):
	### $newLM gt $oldLM || die; # Verify monotonic LM
	# Need to save the content to file $inSerCache.
	# TODO: Figure out whether the content should be decoded first.  
	# If not, should the Content-Type and Content-Encoding headers 
	# be saved with the LM perhaps? Or is there a more efficient way 
	# to save the content to file $inSerCache, such as using 
	# $ua->get($url, ':content_file'=>$filename) ?  See
	# http://search.cpan.org/~gaas/libwww-perl-6.03/lib/LWP/UserAgent.pm
	if ($method ne 'HEAD') {
		&Warn("UPDATING $depUri inSerCache: $inSerCache of $thisUri\n", $DEBUG_CACHES); 
		&MakeParentDirs( $inSerCache );
		$ua->save_content( $inSerCache );
		}
	&SaveLMHeaders($inSerCache, $newLM, $newLMHeader, $newETagHeader);
	}
return $newLM;
}

################### DeserializeToLocalCache ##################
# Update $thisUri's local cache of $depUri's state, by deserializing
# (if necessary) from $thisUri's local serCache of $depUri.
# It is deserialized to $thisUri's node type -- NOT $depUri's node
# type -- so that $thisUri can use it.
# There is nothing to do if there's no deserializer or !$isInput,
# because cache and serCache are the same in that case.
# The cache's LM is *only* used to know if the deserializer needs
# to be run.  It is not used by RequestLatestDependsOns in determining
# freshness.
sub DeserializeToLocalCache
{
@_ == 5 or die;
my ($nm, $thisUri, $depUri, $depLM, $isInput) = @_;
&Warn("DeserializeToLocalCache $thisUri In: $depUri\n", $DEBUG_DETAILS);
&Warn("... with depLM: $depLM isInput: $isInput\n", $DEBUG_DETAILS);
$depLM or die;
return if !$isInput;
my $nmv = $nm->{value};
my $thisVHash = $nmv->{$thisUri} || {};
my $thisType = $thisVHash->{nodeType} || "";
my $fDeserializer = $nmv->{$thisType}->{fDeserializer} || "";
if (!$fDeserializer) {
	&Warn("DeserializeToLocalCache returning due to no fDeserializer\n", $DEBUG_DETAILS);
	return;
	}
my $nmh = $nm->{hash};
my $thisHHash = $nmh->{$thisUri} || {};
my $depSerCache = $thisHHash->{dependsOnSerCache}->{$depUri} || "";
my $depCache = $thisHHash->{dependsOnCache}->{$depUri} || "";
my ($oldCacheLM) = &LookupLMs($thisType, $depCache);
$oldCacheLM ||= "";
my $fExists = $nmv->{$thisType}->{fExists} or die;
my $thisHostRoot = $nmh->{$thisType}->{hostRoot}->{$baseUri} || $basePath;
$oldCacheLM = "" if $oldCacheLM && !&{$fExists}($depCache, $thisHostRoot);
if (!$depLM || $depLM eq $oldCacheLM) {
	&Warn("DeserializeToLocalCache returning due to no depLM or depLM eq oldCacheLM\n", $DEBUG_DETAILS);
	return;
	}
#### TODO: It would be better to store the Content-Type with the serCache
#### and look it up here, instead of assuming that it is what it was
#### originally declared to be.
my $contentType = $thisVHash->{contentType}
	|| $nmv->{$thisType}->{defaultContentType}
	|| "text/plain";
&Warn("UPDATING $depUri local cache: $depCache of $thisUri\n", $DEBUG_CACHES); 
&{$fDeserializer}($depSerCache, $depCache, $contentType, $thisHostRoot) 
	or die "ERROR: Failed to deserialize $depSerCache to $depCache with Content-Type: $contentType\n";
&SaveLMs($thisType, $depCache, $depLM);
&Warn("DeserializeToLocalCache returning (finished).\n", $DEBUG_DETAILS);
}

################### HandleHttpEvent ##################
sub HandleHttpEvent
{
@_ >= 3 or die;
my ($nm, $r, $thisUri, %args) = @_;
&Warn("HandleHttpEvent called: thisUri: $thisUri\n", $DEBUG_DETAILS);
my $thisVHash = $nm->{value}->{$thisUri} || {};
my $thisType = $thisVHash->{nodeType} || "";
if (!$thisType) {
	&Warn("INTERNAL ERROR: HandleHttpEvent called, but $thisUri has no nodeType.\n");
	return Apache2::Const::SERVER_ERROR;
	}
my $callerUri = $args{callerUri} || "";
my $callerLM = $args{callerLM} || "";
my $method = $args{method} || $r->method;
return Apache2::Const::HTTP_METHOD_NOT_ALLOWED 
  if $method ne "HEAD" && $method ne "GET" && $method ne "GRAB" 
	&& $method ne "NOTIFY";
#### TODO QUERY: Update this node's query strings:
%args = &FilterArgs(\%args, @systemArgs);
my $query = &BuildQueryString(%args);
&Warn("HandleHttpEvent query: $query\n", $DEBUG_DETAILS);
&UpdateQueries($nm, $thisUri, $callerUri, $query) 
	if $method eq "GET" || $method eq "HEAD";
####
# TODO: If $r has fresh content, then store it.
&Warn("HandleHttpEvent $method $thisUri From: $callerUri\n", $DEBUG_REQUESTS);
&Warn("... callerLM: $callerLM\n", $DEBUG_DETAILS);
# TODO: Issue #12: Make FreshenSerState return the serState that was just freshened.
my $newThisLM = &FreshenSerState($nm, $method, $thisUri, $callerUri, $callerLM);
####### Ready to generate the HTTP response. ########
my $serState = $thisVHash->{serState} || die;
# TODO: Should use Accept header in choosing contentType?
my $contentType = $thisVHash->{contentType}
	|| $nm->{value}->{$thisType}->{defaultContentType}
	|| "text/plain";
# These work:
# $r->content_type('text/plain');
# $r->content_type('application/rdf+xml');
$r->content_type($contentType);
my ($lmHeader, $eTagHeader) = &LMToHeaders($newThisLM);
# These work:
# "W/" prefix on ETag means that it is weak.
# $r->headers_out->set('ETag' => 'W/"640e9-a-4b269027adb7d;4b142a708a8ad"'); 
# $r->headers_out->set('ETag' => 'W/"fake-etag"'); 
# Don't use this method, because $lmHeader is already formatted:
# $r->set_last_modified($mtime);
$r->headers_out->set('Last-Modified' => $lmHeader) if $lmHeader; 
$r->headers_out->set('ETag' => $eTagHeader) if $eTagHeader; 
# Done setting headers.  Determine status code to return, and
# send content body if 200 and not HEAD.
my $status = $r->meets_conditions();
if($status != Apache2::Const::OK) {
  # $r->status(Apache2::Const::HTTP_NOT_MODIFIED);
  # Returns 304 if appropriate:
  return $status;
  }
# TODO: It might be better to convert {serState} and {state}
# to absolute paths *once*, and store them in $nm.  But {state}
# is a native name -- not necessarily a file name, though it
# is in the case of a FileNode -- whereas {serState} is always
# a filename.
my $serStateAbsPath = &NodeAbsPath($serState);
# Either HEAD or GET.  Set size.
my $size = -s $serStateAbsPath;
$r->set_content_length($size) if defined($size);
if($r->header_only) {
  return $status;
  }
# Not sure if the Content-Location header should be set.  
# It may help people with debugging (so that they can view the serState
# directly), but it could be misused if people start requesting 
# directly from that instead of using the node name.
# Based on my current reading of the HTTP 1.1. spec
# http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.14
# it sounds like it should be safe to return the Content-Location,
# i.e., clients should know that the semantics are different.
$r->headers_out->set('Content-Location' => &PathToUri($serState)); 
# sendfile seems to want a full file system path:
&Warn("Sending file: $serStateAbsPath\n", $DEBUG_DETAILS);
# my $contents = &ReadFile($serStateAbsPath);
# &Warn("[[\n", $DEBUG_DETAILS);
# &Warn("  $contents\n", $DEBUG_DETAILS);
# &Warn("]]\n", $DEBUG_DETAILS);
$r->sendfile($serStateAbsPath);
return Apache2::Const::OK;
}

################### FreshenSerState ##################
sub FreshenSerState
{
@_ == 5 or die;
my ($nm, $method, $thisUri, $callerUri, $callerLM) = @_;
&Warn("FreshenSerState $method $thisUri From: $callerUri\n", $DEBUG_REQUESTS);
&Warn("... callerLM: $callerLM\n", $DEBUG_DETAILS);
my $thisVHash = $nm->{value}->{$thisUri} || die;
my $thisType = $thisVHash->{nodeType} || die;
my $thisTypeVHash = $nm->{value}->{$thisType} || {};
my $fSerializer = $thisTypeVHash->{fSerializer};
my $state = $thisVHash->{state} || die;
my $serState = $thisVHash->{serState} || die;
my $newThisLM = &FreshenState($nm, $method, $thisUri, $callerUri, $callerLM);
&Warn("FreshenState $thisUri returned newThisLM: $newThisLM\n", $DEBUG_DETAILS);
$newThisLM or die;
# For efficiency, don't serialize on HEAD request.  See issue 20.
if ($method eq 'HEAD' || $method eq 'NOTIFY' || !$fSerializer) {
  &Warn("FreshenSerState: No serialization needed. Returning newThisLM: $newThisLM\n", $DEBUG_DETAILS);
  return $newThisLM;
  }
# Need to update serState?
my ($serStateLM) = &LookupLMs($FILE, $serState);
$serStateLM ||= "";
if (!$serStateLM || !-e $serState || ($newThisLM && $newThisLM ne $serStateLM)) {
  ### Allow non-monotonic LM (because they could be checksums):
  ### die if $newThisLM && $serStateLM && $newThisLM lt $serStateLM;
  # TODO: Set $acceptHeader from $r, and use it to choose $contentType:
  # This could be done by making {fSerializer} a hash from $contentType
  # to the serialization function.
  # my $acceptHeader = $r->headers_in->get('Accept') || "";
  # warn "acceptHeader: $acceptHeader\n";
  my $contentType = $thisVHash->{contentType}
	|| $thisTypeVHash->{defaultContentType}
	|| "text/plain";
  # There MUST be a serializer or we would have returned already.
  $fSerializer || die;
  &Warn("UPDATING $thisUri serState: $serState\n", $DEBUG_CACHES); 
  my $thisHostRoot = $nm->{hash}->{$thisType}->{hostRoot}->{$baseUri} || $basePath;
  &{$fSerializer}($serState, $state, $contentType, $thisHostRoot) 
    or die "ERROR: Failed to serialize $state to $serState with Content-Type: $contentType\n";
  $serStateLM = $newThisLM;
  &SaveLMs($FILE, $serState, $serStateLM);
  }
&Warn("FreshenSerState: Returning serStateLM: $serStateLM\n", $DEBUG_DETAILS);
return $serStateLM
}

################### UpdateQueries ###################
# Update the queryStrings received by this node if the $latestQuery
# differs from what was previously requested by $latestUri.
# All $latestUris that are not outputs will be treated as the same
# anonymous $latestUri.
# Also generate a new LM if either the $latestQuery changed and
# $thisUri has no parametersFilter or the set of output queries changed.
sub UpdateQueries
{
@_ == 4 or die;
my ($nm, $thisUri, $latestUri, $latestQuery) = @_;
defined($thisUri) || confess;
defined($latestUri) || confess;
defined($latestQuery) || confess;
&Warn("UpdateQueries(nm, $thisUri, $latestUri, $latestQuery)\n", $DEBUG_DETAILS);
my $pOutputs = $nm->{multi}->{$thisUri}->{outputs} || {};
$latestUri = "" if !$pOutputs->{$latestUri};	# Treat as anonymous requester?
my $thisVHash = $nm->{value}->{$thisUri} or die;
my $parametersFile = $thisVHash->{parametersFile} or die;
my ($lm, $oldLatestQuery, @oldRequesterQueries) = 
	&LookupLMs($FILE, $parametersFile);
# my @results = &LookupLMs($FILE, $parametersFile);
if (@oldRequesterQueries % 2 != 0) {
	&Warn("ODD NUMBER OF ELEMENTS IN HASH ASSIGNMENT after LookupLMs($FILE, $parametersFile)\n", $DEBUG_DETAILS);
	for (my $i=0; $i<@oldRequesterQueries; $i++) {
		&Warn("... oldRequesterQueries[$i]: $oldRequesterQueries[$i]\n", $DEBUG_DETAILS);
		}
	}
$lm ||= "";
my %oldRequesterQueries = @oldRequesterQueries;
my $isNewLatest = !defined($oldLatestQuery) || $latestQuery ne $oldLatestQuery || 0;
my $isNewOutQuery = !defined($oldRequesterQueries{$latestUri})
		|| $latestQuery ne $oldRequesterQueries{$latestUri} || 0;
&Warn("... lm: $lm isNewLatest: $isNewLatest isNewOutQuery: $isNewOutQuery\n", $DEBUG_DETAILS);
if (!$lm || $isNewLatest || $isNewOutQuery) {
	# Save the change.  Gen new LM only if the $latestQuery changed
	# or the set of output queries changed.
	my %newRequesterQueries = %oldRequesterQueries;
	$newRequesterQueries{$latestUri} = $latestQuery;
	my %oldUniqOutQueries = map {($_,1)} values %oldRequesterQueries;
	my %newUniqOutQueries = map {($_,1)} values %newRequesterQueries;
	my $sameQueries = &SameKeys(\%oldUniqOutQueries, \%newUniqOutQueries);
	# my $sameQueries = &KeySubset(\%newUniqOutQueries, \%oldUniqOutQueries);
	&Warn("... sameQueries: $sameQueries\n", $DEBUG_DETAILS);
	$lm = &GenerateNewLM() if !$lm || !$sameQueries 
		|| ($isNewLatest && !$thisVHash->{parametersFilter});
	&SaveLMs($FILE, $parametersFile, $lm, $latestQuery, %newRequesterQueries);
	}
return $lm;
}

################### KeySubset ################### 
# Return true (1) iff the keys of hashRef $pa are a subset of the keys of
# hashref $pb.  I.e., every key of $pa exists as a key of $pb.
sub KeySubset
{
@_ == 2 or die;
my ($pa, $pb) = @_;
defined($pa) && defined($pb) or die;
foreach my $k (keys %{$pa}) {
	return 0 if !exists($pb->{$k});
	}
return 1;
}

################### SameKeys ################### 
# Return true (1) iff the two hashRefs have the same keys.
sub SameKeys
{
@_ == 2 or die;
my ($pa, $pb) = @_;
defined($pa) && defined($pb) or die;
return 0 if scalar(keys %{$pa}) != scalar(keys %{$pb});
foreach my $k (keys %{$pa}) {
	return 0 if !exists($pb->{$k});
	}
foreach my $k (keys %{$pb}) {
	return 0 if !exists($pa->{$k});
	}
return 1;
}

################### FreshenState ################### 
# $callerUri and $callerLM are only used if $method is NOTIFY
sub FreshenState
{
@_ == 5 or die;
my ($nm, $method, $thisUri, $callerUri, $callerLM) = @_;
&Warn("FreshenState $method $thisUri From: $callerUri\n", $DEBUG_REQUESTS);
&Warn("... callerLM: $callerLM\n", $DEBUG_DETAILS);
my $thisVHash = $nm->{value}->{$thisUri};
my ($oldThisLM, %oldDepLMs) = &LookupLMs($URI, $thisUri);
$oldThisLM ||= "";
return $oldThisLM if $method eq "GRAB";
# Run thisUri's update policy for this event:
my $fUpdatePolicy = $thisVHash->{fUpdatePolicy} or die;
my $policySaysFreshen = 
	&{$fUpdatePolicy}($nm, $method, $thisUri, $callerUri, $callerLM);
return $oldThisLM if !$policySaysFreshen;
my ($thisIsStale, $newDepLMs) = 
	&RequestLatestDependsOns($nm, $thisUri, $oldThisLM, $callerUri, $callerLM, \%oldDepLMs);
my $thisType = $thisVHash->{nodeType} or die;
my $state = $thisVHash->{state} or die;
my $thisTypeVHash = $nm->{value}->{$thisType} || {};
my $fExists = $thisTypeVHash->{fExists} or die;
my $thisHostRoot = $nm->{hash}->{$thisType}->{hostRoot}->{$baseUri} || $basePath;
$oldThisLM = "" if !&{$fExists}($state, $thisHostRoot);	# state got deleted?
$thisIsStale = 1 if !$oldThisLM;
my $thisUpdater = $thisVHash->{updater} || "";
$thisUpdater or die "ERROR: Trying to freshen $thisUri but it has no updater!";
# If it's fresh then there's nothing to do, except if there's no updater, 
# in which case we have to generate an LM from static content.
return $oldThisLM if $thisUpdater && !$thisIsStale;
my $thisLHash = $nm->{list}->{$thisUri};
my $thisInputs = $thisLHash->{inputCaches} || [];
my $thisParameters = $thisLHash->{parameterCaches} || [];
# TODO: Figure out what to do if a node is STUCK, i.e., inputs
# have changed but there is no updater.
die "ERROR: Node $thisUri is STUCK: Inputs but no updater. " 
	if @{$thisInputs} && !$thisUpdater;
my $fRunUpdater = $thisTypeVHash->{fRunUpdater} or die;
# If there is no updater then it is up to $fRunUpdater to generate
# an LM for the static state.
if ($thisUpdater) {
	&Warn("UPDATING $thisUri {$thisUpdater} state: $state\n", $DEBUG_NODE_UPDATES); 
	}
else	{
	&Warn("Generating LM of static node: $thisUri\n", $DEBUG_CHANGES); 
	}
my $newThisLM = &{$fRunUpdater}($nm, $thisUri, $thisUpdater, $state, 
	$thisInputs, $thisParameters, $oldThisLM, $callerUri, $callerLM);
&Warn("WARNING: fRunUpdater on $thisUri $thisUpdater returned false LM\n") if !$newThisLM;
$newThisLM or die;
&SaveLMs($URI, $thisUri, $newThisLM, %{$newDepLMs});
return $newThisLM if $newThisLM eq $oldThisLM;
### Allow non-monotonic LM (because they could be checksums):
### $newThisLM gt $oldThisLM or die;
# Notify outputs of change:
my @outputs = sort keys %{$nm->{multi}->{$thisUri}->{outputs}};
foreach my $outUri (@outputs) {
	next if $outUri eq $callerUri;
	&Notify($nm, $outUri, $thisUri, $newThisLM);
	}
return $newThisLM;
}

################### Notify ################### 
sub Notify
{
@_ == 4 or die;
my ($nm, $thisUri, $callerUri, $callerLM) = @_;
&Warn("Notify $thisUri From: $callerUri\n", $DEBUG_REQUESTS);
&Warn("... callerLM: $callerLM\n", $DEBUG_DETAILS);
# Avoid unused var warning:
($nm, $thisUri, $callerUri, $callerLM) = 
($nm, $thisUri, $callerUri, $callerLM);
# TODO: Queue a NOTIFY event.
}

################### RequestLatestDependsOns ################### 
# Logic table for each $depUri:
#       is      known   is      same    same
#       Input   Fresh   Node    Server  Type    Action
#       0       0       0       x       x       Foreign HEAD
#       0       0       1       0       x       Foreign HEAD
#       0       0       1       1       0       Neighbor HEAD
#       0       0       1       1       1       Local HEAD/GET*
#       0       1       x       x       x       Nothing to do
#       1       0       0       x       x       Foreign GET
#       1       0       1       0       x       Foreign GET
#       1       0       1       1       0       Neighbor GET
#       1       0       1       1       1       Local GET
#       1       1       0       x       x       Foreign GET/GRAB**
#       1       1       1       0       x       Foreign GRAB
#       1       1       1       1       0       Neighbor GRAB
#       1       1       1       1       1       Nothing to do
#  * No difference between HEAD and GET for local node.
#  ** No difference between GET and GRAB for non-node.
sub RequestLatestDependsOns
{
@_ == 6 or die;
my ($nm, $thisUri, $oldThisLM, $callerUri, $callerLM, $oldDepLMs) = @_;
&Warn("RequestLatestDependsOn(nm, $thisUri, $oldThisLM, $callerUri, $callerLM, $oldDepLMs) called\n", $DEBUG_DETAILS);
# callerUri and callerLM are only used to avoid requesting the latest 
# state from an input/parameter that is already known fresh, because 
# it was the one that notified thisUri.
# Thus, they are not used when this was called because of a GET.
my $thisVHash = $nm->{value}->{$thisUri};
my $thisHHash = $nm->{hash}->{$thisUri};
my $thisMHash = $nm->{multi}->{$thisUri};
my $thisMHashInputs = $thisMHash->{inputs};
my $thisMHashParameters = $thisMHash->{parameters};
my $thisMHashDependsOn = $thisMHash->{dependsOn};
my $thisType = $thisVHash->{nodeType};
my $thisTypeVHash = $nm->{value}->{$thisType} || {};
my $thisIsStale = 0;
my $newDepLMs = {};
#### TODO QUERY: lookup this node's query parameters and filter them 
#### so that they can be passed upstream.
my $parametersFile = $thisVHash->{parametersFile} or die;
my ($parametersLM, $latestQuery, %requesterQueries) = 
	&LookupLMs($FILE, $parametersFile);
$parametersLM ||= "";
my $parametersFileUri = $thisVHash->{parametersFileUri} or die;
my $oldParametersLM = $oldDepLMs->{$parametersFileUri};
# Treat first time as changed:
my $pChanged = !defined($oldParametersLM) || 0;
$oldParametersLM ||= "";
$pChanged = 1 if ($parametersLM ne $oldParametersLM);
$thisIsStale = 1 if $pChanged;
if ($pChanged) {
  &Warn("UPDATED query parameters of $thisUri\n", $DEBUG_PARAM_UPDATES);
} else {
  &Warn("NO CHANGE to query parameters of $thisUri\n", $DEBUG_CHANGES);
  }
&Warn("... oldParametersLM: $oldParametersLM parametersLM: $parametersLM\n", $DEBUG_DETAILS);
$newDepLMs->{$parametersFileUri} = $parametersLM;
#### TODO QUERY: Make this call the user's parameterFilter
my $fRunParametersFilter = $thisTypeVHash->{fRunParametersFilter} or die;
my $parametersFilter = $thisVHash->{parametersFilter} || "";
$fRunParametersFilter = \&LatestRunParametersFilter if !$parametersFilter;
my $pThisInputs = $nm->{list}->{$thisUri}->{inputs} || [];
my @requesterQueries = sort values %requesterQueries;
my $pUpstreamQueries = &{$fRunParametersFilter}($nm, $thisUri, $parametersFilter, $pThisInputs, $latestQuery, \@requesterQueries);
&Warn("Ran parametersFilter\n", $DEBUG_DETAILS);
####
foreach my $depUri (sort keys %{$thisMHashDependsOn}) {
  # In case $thisUri dependsOn itself, ignore it.
  # See issue 58.
  next if $depUri eq $thisUri;
  # Bear in mind that a node may dependsOn a non-node arbitrary http 
  # or file:// source, so $depVHash may be undef.
  my $depVHash = $nm->{value}->{$depUri} || {};
  my $depType = $depVHash->{nodeType} || "";
  my $newDepLM;
  my $method = 'GET';
  my $depLM = "";
  my $depQuery = "";
  $depQuery = ($pUpstreamQueries->{$depUri} || "") if $depType;
  # confess "INTERNAL ERROR: depUri: $depUri depQuery: $depQuery\n" if $depQuery =~ m/\Ahttp:/;
  my $isInput = $thisMHashInputs->{$depUri} 
	|| $thisMHashParameters->{$depUri} || 0;
  # TODO: Future optimization: if depUri is in %knownFresh ...
  my $knownFresh = ($depUri eq $callerUri) && $callerLM && 1;
  $knownFresh ||= 0;	# Nicer for logs if false.
  if ($knownFresh) {
    $method = 'GRAB';
    $depLM = $callerLM;
    }
  elsif (!$isInput) {
    $method = 'HEAD';
    }
  my $isSameServer = &IsSameServer($thisUri, $depUri) || 0;
  my $isSameType   = &IsSameType($nm, $thisType, $depType) || 0;
  #### TODO QUERY: Update local $depUri's requester queries:
  &UpdateQueries($nm, $depUri, $thisUri, $depQuery) 
	if $depType && $isSameServer;
  ####
  &Warn("$thisUri depUri: $depUri depType: $depType method: $method depLM: $depLM\n", $DEBUG_DETAILS);
  &Warn("... isSameServer: $isSameServer isSameType: $isSameType knownFresh: $knownFresh isInput: $isInput\n", $DEBUG_DETAILS);
  if ($knownFresh && !$isInput) {
    # Nothing to do, because we don't need $depUri's content.
    $newDepLM = $callerLM;
    &Warn("Known fresh depUri: $depUri\n", $DEBUG_DETAILS);
    }
  elsif (!$depType || !$isSameServer) {
    # Foreign node or non-node.
    &Warn("Foreign or non-node.\n", $DEBUG_DETAILS);
    #### TODO QUERY: Update $depUri's requester queries also:
    $newDepLM = &ForeignSendHttpRequest($nm, $method, $thisUri, $depUri, $depLM, $depQuery);
    &DeserializeToLocalCache($nm, $thisUri, $depUri, $newDepLM, $isInput);
    }
  elsif (!$isSameType) {
    # Neighbor: Same server but different type.
    &Warn("Same server, different type.\n", $DEBUG_DETAILS);
    $newDepLM = &FreshenSerState($nm, $method, $depUri, $thisUri, $oldThisLM);
    &DeserializeToLocalCache($nm, $thisUri, $depUri, $newDepLM, $isInput);
    }
  elsif ($knownFresh) {
    # Nothing to do, because it's local, same type and already known fresh.
    $newDepLM = $callerLM;
    &Warn("Nothing to do: Caller known fresh and local.\n", $DEBUG_DETAILS);
    }
  else {
    # Local: Same server and type, but not known fresh.  When local, GET==HEAD.
    &Warn("Same server and type.\n", $DEBUG_DETAILS);
    $newDepLM = &FreshenState($nm, 'GET', $depUri, "", "");
    &Warn("FreshenState $depUri returned newDepLM: $newDepLM\n", $DEBUG_DETAILS);
    }
  my $oldDepLM = $oldDepLMs->{$depUri} || "";
  my $depChanged = !$oldDepLM || ($newDepLM && $newDepLM ne $oldDepLM);
  $thisIsStale = 1 if $depChanged;
  $newDepLMs->{$depUri} = $newDepLM;
  my $status = $depChanged ? "UPDATED" : "NO CHANGE to";
  if ($depChanged) {
    &Warn("UPDATED depUri $depUri of $thisUri\n", $DEBUG_CHANGES);
    } else {
    &Warn("NO CHANGE to depUri $depUri of $thisUri\n", $DEBUG_CHANGES);
    }
  &Warn("... oldDepLM: $oldDepLM newDepLM: $newDepLM stale: $thisIsStale\n", $DEBUG_DETAILS);
  }
&Warn("RequestLatestDependsOn(nm, $thisUri, $oldThisLM, $callerUri, $callerLM, $oldDepLMs) returning: $thisIsStale\n", $DEBUG_DETAILS);
return( $thisIsStale, $newDepLMs )
}

################### LoadNodeMetadata #################
#
sub LoadNodeMetadata
{
@_ == 3 or die;
my ($nm, $ontFile, $configFile) = @_;
my %config = &CheatLoadN3($ontFile, $configFile);
my $nmv = $nm->{value};
my $nml = $nm->{list};
my $nmh = $nm->{hash};
my $nmm = $nm->{multi};
foreach my $k (sort keys %config) {
	# &Warn("LoadNodeMetadata key: $k\n", $DEBUG_DETAILS);
	my ($s, $p) = split(/\s+/, $k) or die;
	my $v = $config{$k};
	die if !defined($v);
	my @vList = split(/\s+/, $v); 
	# If there is an odd number of items, then it cannot be a hash.
	my %hHash = ();
	%hHash = @vList if (scalar(@vList) % 2 == 0);
	my %mHash = map { ($_, 1) } @vList;
	$nmv->{$s}->{$p} = $v;
	$nml->{$s}->{$p} = \@vList;
	$nmh->{$s}->{$p} = \%hHash;
	$nmm->{$s}->{$p} = \%mHash;
	# &Warn("  $s -> $p -> $v\n", $DEBUG_DETAILS);
	}
&PresetGenericDefaults($nm);
# Run the initialization function to set defaults for each node type 
# (i.e., wrapper type), starting with leaf nodes and working up the hierarchy.
my @leaves = &LeafClasses($nm, sort keys %{$nmm->{Node}->{subClass}});
my %done = ();
while(@leaves) {
	my $nodeType = shift @leaves;
	next if $done{$nodeType};
	$done{$nodeType} = 1;
	my @superClasses = sort keys %{$nmm->{$nodeType}->{$subClassOf}};
	push(@leaves, @superClasses);
	my $fSetNodeDefaults = $nmv->{$nodeType}->{fSetNodeDefaults};
	next if !$fSetNodeDefaults;
	&{$fSetNodeDefaults}($nm);
	}
# Error check: make sure there is no nodeType $FILE or $URI,
# otherwise there will be a name clash in NameToLmFile.
die "INTERNAL ERROR: $FILE $subClassOf Node\n" if $nmm->{$FILE}->{$subClassOf}->{Node};
die "INTERNAL ERROR: $URI $subClassOf Node\n" if $nmm->{$URI}->{$subClassOf}->{Node};
return $nm;
}

################### PresetGenericDefaults #################
# Preset essential generic $nmv, $nml, $nmh defaults that must be set
# before nodeType-specific defaults are set.  In particular, the
# following are set for every node: nodeType.  Plus the following
# are set for every node on this server:
# stateOriginal, state, serState, stderr.
sub PresetGenericDefaults
{
@_ == 1 or die;
my ($nm) = @_;
my $nmv = $nm->{value};
my $nml = $nm->{list};
my $nmh = $nm->{hash};
my $nmm = $nm->{multi};
# &Warn("PresetGenericDefaults:\n");
# First set defaults that are set directly on each node: 
# nodeType, state, serState, stderr, fUpdatePolicy.
my @allNodes = sort keys %{$nmm->{Node}->{member}};
foreach my $thisUri (@allNodes) 
  {
  # Make life easier in this loop:
  my $thisVHash = $nmv->{$thisUri} or die;
  my $thisLHash = $nml->{$thisUri} or die;
  my $thisMHash = $nmm->{$thisUri} or die;
  # Set nodeType, which should be most specific node type.
  my @types = sort keys %{$thisMHash->{a}};
  my @nodeTypes = &LeafClasses($nm, @types);
  die "INTERNAL ERROR: Multiple nodeTypes: (@nodeTypes) for node $thisUri\n" if @nodeTypes > 1;
  die if @nodeTypes < 1;
  my $thisType = $nodeTypes[0];
  $thisVHash->{nodeType} = $thisType;
  # Nothing more to do if $thisUri is not hosted on this server:
  next if !&IsSameServer($baseUri, $thisUri);
  # Save original state before setting it to a default value:
  $thisVHash->{stateOriginal} = $thisVHash->{state};
  # Set state and serState if not set.  
  # state is a native name; serState is a file path.
  my $fUriToNativeName = $nmv->{$thisType}->{fUriToNativeName} || "";
  my $defaultStateUri = "$baseUri/cache/" . &QuickName($thisUri) . "/state";
  my $thisHostRoot = $nmh->{$thisType}->{hostRoot}->{$baseUri} || $basePath;
  my $defaultState = $defaultStateUri;
  $defaultState = &{$fUriToNativeName}($defaultState, $baseUri, $thisHostRoot) 
	if $fUriToNativeName;
  my $thisName = $thisUri;
  $thisName = &{$fUriToNativeName}($thisUri, $baseUri, $thisHostRoot)
	if $fUriToNativeName;
  ### Default each Node to have an updater that is the node name
  ### with an option file extension:
  my $thisPath = &UriToPath($thisUri);
  my $updaterFileExtensionsListRef = $nml->{$thisType}->{updaterFileExtensions}
	|| [];
  ####### TODO: Should this look for native names instead of file paths?
  ####### E.g., java class name
  $thisVHash->{updater} ||= &FindUpdater($thisPath, @{$updaterFileExtensionsListRef});
  $thisVHash->{updater} or &Warn("WARNING: $thisUri has no updater!\n");
  $thisVHash->{state} ||= 
    $thisVHash->{updater} ? $defaultState : $thisName;
  my $hash = &HashName($URI, $thisUri);
  $thisVHash->{serState} ||= 
    $nmv->{$thisType}->{fSerializer} ?
      "$basePath/cache/" . &QuickName($thisUri) . "/serState"
      : $thisVHash->{state};
  #### TODO QUERY: Add parametersFile as an implicit input:
  $nmv->{$thisUri}->{parametersFile} ||= 
	  "$basePath/cache/" . &QuickName($thisUri) . "/parametersFile";
  $nmv->{$thisUri}->{parametersFileUri} ||= 
	  # "file://$basePath/cache/" . &QuickName($thisUri) . "/parametersFile";
	  "file://" . $nmv->{$thisUri}->{parametersFile};
  ####
  # For capturing stderr:
  $nmv->{$thisUri}->{stderr} ||= 
	  "$basePath/cache/" . &QuickName($thisUri) . "/stderr";
  $thisVHash->{fUpdatePolicy} ||= \&LazyUpdatePolicy;
  #### TODO: If we change to use the node name as the updater name, then
  #### MakeValuesAbsoluteUris will no longer be needed.
  # Simplify later code (needed because upaters are strings -- see issue 30):
  &MakeValuesAbsoluteUris($nmv, $nml, $nmh, $nmm, $thisUri, "inputs");
  &MakeValuesAbsoluteUris($nmv, $nml, $nmh, $nmm, $thisUri, "parameters");
  &MakeValuesAbsoluteUris($nmv, $nml, $nmh, $nmm, $thisUri, "dependsOn");
  #### TODO: {inputs} has not been set yet, so maybe this should be
  #### moved later.
  &Warn("WARNING: Node $thisUri has inputs but no updater ")
	if !$thisVHash->{updater} && @{$thisLHash->{inputs}};
  # Initialize the list of outputs (actually inverse dependsOn) for each node:
  $nmm->{$thisUri}->{outputs} = {};
  }

# Now go through each node again, setting values related to each
# node's dependsOns, which may make use of properties that were
# set in the previous loop.
foreach my $thisUri (@allNodes) 
  {
  # Nothing to do if $thisUri is not hosted on this server:
  next if !&IsSameServer($baseUri, $thisUri);
  # Make life easier in this loop:
  my $thisVHash = $nmv->{$thisUri};
  my $thisLHash = $nml->{$thisUri};
  my $thisHHash = $nmh->{$thisUri};
  my $thisMHash = $nmm->{$thisUri};
  my $thisType = $thisVHash->{nodeType};
  # The dependsOnCache hash is used for inputs from other environments
  # and maps from dependsOn URIs (or inputs/parameter URIs) to the native names 
  # that will be used by $thisUri's updater when
  # it is invoked.  It will either use a new name (if the input is from
  # a different environment) or the input's state directly (if in the 
  # same env).  A non-node input dependsOn is treated like a foreign
  # node with no serializer.  
  # The dependsOnSerCache hash similarly maps
  # from dependsOn URIs to the local serCaches (i.e., file names of 
  # inputs) that will be used to refresh the local cache if the
  # input is foreign.  However, since different node types within
  # the same server can share the serialized inputs, then 
  # the dependsOnSerCache may be set using the input's serState, since
  # both will be filenames.  (Serialized content is always in a file.)
  # Factors that affect these settings:
  #  A. Is $depUri a node? It may be any other URI data source (http: or file:).
  #  B. Is $depUri on the same server (as $thisUri)?
  #     If so, its serCache can be shared with other nodes on this server.
  #  C. Is $depType the same node type $thisType?
  #     If so (and on same server) then the node's state can be accessed directly.
  #  D. Does $thisType have a deserializer?
  #     If not, then 'cache' will be the same as serCache.
  #  E. Is $depUri an input (or parameter)?  
  #     If not, then 'cache' will be the same as serCache.
  #  F. Does $thisType have a fUriToNativeName function?
  #     If so, then it will be used to generate a native name for 'cache'.
  $thisHHash->{dependsOnCache} ||= {};
  $thisHHash->{dependsOnSerCache} ||= {};
  my $fDeserializer = $nmv->{$thisType}->{fDeserializer} || "";
  my $thisMHashInputs = $thisMHash->{inputs};
  my $thisMHashParameters = $thisMHash->{parameters};
  foreach my $depUri (sort keys %{$thisMHash->{dependsOn}}) {
    # Ensure non-null hashrefs for all deps (because they may not be nodes):
    $nmv->{$depUri} ||= {};
    $nml->{$depUri} ||= {};
    $nmh->{$depUri} ||= {};
    $nmm->{$depUri} ||= {};
    # $depType will be false if $depUri is not a node:
    my $depType = $nmv->{$depUri}->{nodeType} || "";
    # First set dependsOnSerCache.
    if ($depType && &IsSameServer($baseUri, $depUri)) {
      # Same server, so re-use the input's serState.
      $thisHHash->{dependsOnSerCache}->{$depUri} = $nmv->{$depUri}->{serState};
      }
    else {
      # Different servers, so make up a new file path.
      # dependsOnSerCache file path does not need to contain $thisType, because 
      # different node types on the same server can share the same serCaches.
      my $depSerCache = "$basePath/cache/" . &QuickName($depUri) . "/serCache";
      $thisHHash->{dependsOnSerCache}->{$depUri} = $depSerCache;
      }
    # Now set dependsOnCache.
    my $isInput = $thisMHashInputs->{$depUri} 
	|| $thisMHashParameters->{$depUri} || 0;
    if (&IsSameServer($baseUri, $depUri) && &IsSameType($nm, $thisType, $depType)) {
      # Same env.  Reuse the input's state.
      $thisHHash->{dependsOnCache}->{$depUri} = $nmv->{$depUri}->{state};
      # warn "thisUri: $thisUri depUri: $depUri Path 1\n";
      }
    elsif ($fDeserializer && $isInput) {
      # There is a deserializer, so we must create a new {cache} name.
      # Create a URI and convert it
      # (if necessary) to an appropriate native name.
      my $fUriToNativeName = $nmv->{$thisType}->{fUriToNativeName};
      my $thisHostRoot = $nmh->{$thisType}->{hostRoot}->{$baseUri} || $basePath;
      # Default to a URI if there is no fUriToNativeName:
      my $cache = "$baseUri/cache/$thisType/" . &QuickName($depUri) . "/cache";
      $cache = &{$fUriToNativeName}($cache, $baseUri, $thisHostRoot) 
		if $fUriToNativeName;
      $thisHHash->{dependsOnCache}->{$depUri} = $cache;
      # warn "thisUri: $thisUri depUri: $depUri Path 2\n";
      }
    else {
      # No deserializer or not an input, so dependsOnCache will be 
      # the same as dependsOnSerCache.
      my $path = $thisHHash->{dependsOnSerCache}->{$depUri};
      $thisHHash->{dependsOnCache}->{$depUri} = $path;
      # warn "thisUri: $thisUri depUri: $depUri Path 3\n";
      }
    # my $don = $thisHHash->{dependsOnCache}->{$depUri};
    # my $dosn = $thisHHash->{dependsOnSerCache}->{$depUri};
    # warn "thisUri: $thisUri depUri: $depUri $depType $don $dosn\n";
    #
    # Set the list of outputs (actually inverse dependsOn) for each node:
    $nmm->{$depUri}->{outputs}->{$thisUri} = 1 if $depType;
    }
  # For convenience, Set the list of input native names for this node.
  $thisLHash->{inputCaches} ||= [];
  foreach my $inUri (@{$thisLHash->{inputs}}) {
    my $inCache = $thisHHash->{dependsOnCache}->{$inUri};
    push(@{$thisLHash->{inputCaches}}, $inCache);
    }
  # For convenience, Set the list of parameter native names for this node.
  $thisLHash->{parameterCaches} ||= [];
  foreach my $pUri (@{$thisLHash->{parameters}}) {
    my $pCache = $thisHHash->{dependsOnCache}->{$pUri};
    push(@{$thisLHash->{parameterCaches}}, $pCache);
    }
  }
}

################# MakeValuesAbsoluteUris ####################
sub MakeValuesAbsoluteUris 
{
@_ == 6 or die;
my ($nmv, $nml, $nmh, $nmm, $thisUri, $predicate) = @_;
my $oldV = $nmv->{$thisUri}->{$predicate} || "";
my $oldL = $nml->{$thisUri}->{$predicate} || [];
my $oldH = $nmh->{$thisUri}->{$predicate} || {};
my $oldM = $nmm->{$thisUri}->{$predicate} || {};
# In the case of a hash, it is the key that is made absolute:
my %hhash = map {(&NodeAbsUri($_), $oldH->{$_})} keys %{$oldH};
my %mhash = map {(&NodeAbsUri($_), $oldM->{$_})} keys %{$oldM};
my @list = map {&NodeAbsUri($_)} @{$oldL};
my $value = join(" ", @list);
$nmv->{$thisUri}->{$predicate} = $value;
$nml->{$thisUri}->{$predicate} = \@list;
$nmh->{$thisUri}->{$predicate} = \%hhash;
$nmm->{$thisUri}->{$predicate} = \%mhash;
return;
}

################### FindUpdater ################### 
# Use the updaterFileExtensions search list to find an updater file
# based on the node path.  The node path itself is always checked first.
# The file path of the first one that exists is returned.  Called: 
#   &FindUpdater($thisPath, @{$updaterFileExtensionsListRef});
# File extensions include the period: (".pl", ".sh")
# The empty string is returned if no updater is found.
sub FindUpdater
{
@_ >= 1 || die;
my $thisPath = shift @_;
my @updaterFileExtensions = ("", @_);
foreach my $ext (@updaterFileExtensions) {
  my $updaterPath = "$thisPath$ext";
  return($updaterPath) if -e $updaterPath;
  }
return("");
}

################### EagerUpdatePolicy ################### 
# Return 1 iff $thisUri should be freshened according to eager update policy.
# $method is one of qw(GET HEAD NOTIFY). It is never GRAB, because there
# is never any updating involved with GRAB.
sub EagerUpdatePolicy
{
@_ == 5 or die;
my ($nm, $method, $thisUri, $callerUri, $callerLM) = @_;
# Avoid unused var warning:
($nm, $method, $thisUri, $callerUri, $callerLM) = 
($nm, $method, $thisUri, $callerUri, $callerLM);
&Warn("EagerUpdatePolicy(\$nm, $method, $thisUri, $callerUri, $callerLM) Called\n", $DEBUG_DETAILS);
return 1 if $method eq "GET";
return 1 if $method eq "HEAD";
die if $method ne "NOTIFY";
#### TODO: Implement this.
die "INTERNAL ERROR: EagerUpdatePolicy not implemented\n ";
}

################### LazyUpdatePolicy ################### 
# Return 1 iff $thisUri should be freshened according to lazy update policy.
# $method is one of qw(GET HEAD NOTIFY). It is never GRAB, because there
# is never any updating involved with GRAB.
sub LazyUpdatePolicy
{
@_ == 5 or die;
my ($nm, $method, $thisUri, $callerUri, $callerLM) = @_;
# Avoid unused var warning:
($nm, $method, $thisUri, $callerUri, $callerLM) = 
($nm, $method, $thisUri, $callerUri, $callerLM);
return 1 if $method eq "GET";
return 1 if $method eq "HEAD";
return 0 if $method eq "NOTIFY";
die;
}

################### LeafClasses #################
# Given a list of classes (with rdfs:subClassOf relations in $nmv, $nml, $nmh), 
# return the ones that are not a 
# superclass of any of them.  The list of classes is expected to
# be complete, e.g., if you have:
#	:a rdfs:subClassOf :b .
#	:b rdfs:subClassOf :c .
# then if :a is in the given list of classes then :b (and :c) must be also.
sub LeafClasses
{
@_ >= 1 or die;
my ($nm, @classes) = @_;
my $nmm = $nm->{multi};
my @leaves = ();
# Simple n-squared algorithm should be okay for small numbers of classes:
foreach my $t (@classes) {
	my $isSuperclass = 0;
	foreach my $subType (@classes) {
		next if $t eq $subType;
		next if !$nmm->{$subType};
		next if !$nmm->{$subType}->{$subClassOf};
		next if !$nmm->{$subType}->{$subClassOf}->{$t};
		$isSuperclass = 1;
		last;
		}
	push(@leaves, $t) if !$isSuperclass;
	}
return @leaves;
}

################### BuildQueryString #################
# Given a hash of key/value pairs, escape both keys and values and
# put them into a query string (not including the "?"), which is returned.
# The opposite of ParseQueryString.
sub BuildQueryString
{
my %args = @_;
# From http://www.ietf.org/rfc/rfc3986.txt
# query         = *( pchar / "/" / "?" )
# pchar         = unreserved / pct-encoded / sub-delims / ":" / "@"
# unreserved    = ALPHA / DIGIT / "-" / "." / "_" / "~"
# sub-delims    = "!" / "$" / "&" / "'" / "(" / ")"
#                / "*" / "+" / "," / ";" / "="
# 
# URI::Escape's default $cRange: "^A-Za-z0-9\-\._~"
# but we want to allow more characters in the query strings if they
# are not harmful
my $cRange = "^A-Za-z0-9" . quotemeta('-._~!$()+,;');
my $args = join("&", 
	map 	{ 
		die if !defined($_);
		die if !defined($args{$_});
		uri_escape($_, $cRange) . "=" . uri_escape($args{$_}, $cRange) 
		}
	sort keys %args);
return $args;
}

################### ParseQueryString #################
# Returns a hash of key/value pairs, with both keys and values unescaped.
# If the same key appears more than once in the query string,
# the last value given wins.
# The opposite of BuildQueryString.
# TODO: Not sure this function is needed.  Maybe $r->param can be used
# instead?  See:
# https://metacpan.org/module/Apache2::Request#param
sub ParseQueryString
{
my $args = shift || "";
my %args = map { 
	my ($k,$v) = split(/\=/, $_); 
	$v = "" if !defined($v); 
	$k = "" if !defined($k); 
	(uri_unescape($k), uri_unescape($v))
	} split(/\&/, $args);
return %args;
}

################### CheatLoadN3 #####################
# Not proper n3 parsing, but good enough for simple POC.
# Returns a hash map that maps: "$s $p" --> $o
# Global $pipelinePrefix is also stripped off from terms.
# Example: "http://localhost/a state" --> "c/cp-state.txt"
sub CheatLoadN3
{
my $ontFile = shift;
my $configFile = shift;
$configFile || die;
-e $configFile || die;
my $cwmCmd = "cwm --n3=ps $ontFile $internalsFile $configFile --think |";
&PrintLog("cwmCmd: $cwmCmd\n");
open(my $fh, $cwmCmd) || die;
my $nc = " " . join(" ", map { chomp; 
	s/^\s*\#.*//; 		# Strip full line comments
	s/\.(\W)/ .$1/g; 	# Add space before period except in a word
	$_ } <$fh>) . " ";
close($fh);
# &PrintLog("-" x 60 . "\n") if $debug;
# &PrintLog("nc: $nc\n") if $debug;
# &PrintLog("-" x 60 . "\n") if $debug;
while ($nc =~ s/\{[^\}]*\}/ /) {}	# Delete subgraphs: { ... } 
my @triples = grep { m/\S/ } 
	map { s/[()\"]/ /g; 		# Strip: ( ) "
		s/<([^<>\s]+)>/$1/g; 	# Strip < > but Keep empty <>
		s/\A\s+//; s/\s+\Z//; 
		s/\A\s*\@.*//; s/\s\s+/ /g; $_ } 
	split(/\s+\./, $nc);
my $nTriples = scalar @triples;
&PrintLog("nTriples: $nTriples\n") if $debug;
# &PrintLog("-" x 60 . "\n") if $debug;
# &PrintLog("triples: \n" . join("\n", @triples) . "\n") if $debug;
&PrintLog("-" x 60 . "\n") if $debug;
my %config = ();
foreach my $t (@triples) {
	# Strip ont prefix from terms:
	$t = join(" ", map { s/\A$pipelinePrefix([a-zA-Z])/$1/;	$_ }
		split(/\s+/, $t));
	# Convert rdfs: namespace to "rdfs:" prefix:
	$t = join(" ", map { s/\A$rdfsPrefix([a-zA-Z])/rdfs:$1/;	$_ }
		split(/\s+/, $t));
	my ($s, $p, $o) = split(/\s+/, $t, 3);
	next if !defined($o) || $0 eq "";
	# $o may actually be a space-separate list of URIs
	# &PrintLog("  s: $s p: $p o: $o\n") if $debug;
	# Append additional values for the same property:
	$config{"$s $p"} = "" if !exists($config{"$s $p"});
	$config{"$s $p"} .= " " if $config{"$s $p"};
	$config{"$s $p"} .= $o;
	}
&PrintLog("-" x 60 . "\n") if $debug;
return %config;
}

############ WriteFile ##########
# Write a file.  Examples:
#   &WriteFile("/tmp/foo", $all)   # Same as &WriteFile(">/tmp/foo", all);
#   &WriteFile(">$f", $all)
#   &WriteFile(">>$f", $all)
# Parent directories are automatically created as needed.
sub WriteFile
{
@_ == 2 || die;
my ($f, $all) = @_;
my $ff = (($f =~ m/\A\>/) ? $f : ">$f");    # Default to ">$f"
my $nameOnly = $ff;
$nameOnly =~ s/\A\>(\>?)//;
&MakeParentDirs($nameOnly);
open(my $fh, $ff) || confess "WriteFile: open failed of $ff : $!";
print $fh $all;
close($fh) || die;
}

############ ReadFile ##########
# Read a file and return its contents or "" if the file does not exist.  
# Examples:
#   my $all = &ReadFile("<$f")
sub ReadFile
{
@_ == 1 || die;
my ($f) = @_;
open(my $fh, $f) || return "";
my $all = join("", <$fh>);
close($fh) || die;
return $all;
}

################ SafeBase64Hash ################
# Hash a given string, returning the hash as a base64-encoded string,
# after changing characters that would not be safe in a filename
# or URI into filename- and URI-safe characters.
# Also prepend "h" to the resulting hash ensure that it never starts with "-",
# which might otherwise be mistaken for a command option in linux.
sub SafeBase64Hash
{
my $n = shift || die;
my $hash = "h" . md4_base64($n);
# Ensure that it is filename- and URI-friendly:
$hash =~ tr|+/=|\-_|d;
return $hash;
}

############### HashName ###############
# $nameType must match m/\A[a-zA-Z_]\w*\Z/
sub HashName
{
@_ == 2 || die;
my ($nameType, $name) = @_;
our %templates;
my $template = $templates{$nameType};
if (!$template) {
	our $hashMapTemplate ||= "$basePath/cache/NAMETYPE/{}/hashMapFile.txt";
	$template = $hashMapTemplate;
	confess "Bad basePath: $basePath" if $basePath =~ m/NAMETYPE/;
	confess "Bad nameType: $nameType" if $nameType !~ m/\A[a-zA-Z_]\w*\Z/;
	$template =~ s/NAMETYPE/$nameType/;
	$templates{$nameType} = $template;
	}
return &HashTemplateName($template, $name);
}

############### HashTemplateName ###############
# Called as: my $hash = &HashTemplateName($template, $name);
#
# Create a unique, filename- and URI-friendly hash of the given $name,
# (which must not: be the empty string, contain newline, or
# have leading or trailing whitespace) using $template as a filename 
# template for persisting the $hash-to-$name association.
# Actually the hash is only guaranteed to be unique within a template:
# the same hash may be used for different templates.
# The $template must contain {}, which will be replaced with
# the generated hash, which is guaranteed filename and URI friendly
# by &SafeBase64Hash.  Each $name-to-$hash association is stored
# in a separate file whose name is determined by the $template.
# However, the associations are also cached in memory in
# %nameToHashCache and %hashToNameCache to avoid file access
# when possible.
#
# The algorithm computes a hash, and if there is a collision,
# then the hash is appended to the current $name and we try again
# until we find a hash that is unique.  For example, if foo hashes to
# 44, but the slot for 44 is already taken (collision), then we
# try hashing foo44.  If that hashes to xx, and that slot is also
# taken (collision), then we try hashing foo44xx, etc.  Once we
# find an unused slot (hash), we store the hash and original name
# in the $hashMapFile for that hash.  
#
# When checking for collisions, there
# are basically three cases to handle: empty hashMapFile (unique hash);
# matching hashMapFile (found); or collision. However, the cases are 
# complicated by the fact that we cache the hashMapFile contents
# for fast lookup.
sub HashTemplateName
{
my $template = shift || confess "[INTERNAL ERROR] Missing template argument";
my $name = shift;
confess "[INTERNAL ERROR] Missing name argument" if !defined($name);
confess "[INTERNAL ERROR] Empty name argument" if $name eq "";
# $name must not contain newline char:
confess "[ERROR] Attempt to HashTemplateName a name containing a newline: {$name}" 
	if $name =~ m/\n/s;
confess "[ERROR] Attempt to HashTemplateName a name with leading or trailing whitespace: {$name}" 
	if $name =~ m/\A\s/ || $name =~ m/\s\Z/;
my $originalName = $name;
# Repeatedly try until we've found (or looked up) the unique hash for $name.
my $maxCollisions = 20;
my $nCollisions = 0;
&Warn("HashTemplateName($template, $name) called\n");
while (1) {
	if ($nCollisions >= $maxCollisions) {
		confess "[ERROR] Too many hash collisions ($nCollisions) when hashing $originalName";
		}
	$nCollisions++;
	&Warn("HashTemplateName iteration $nCollisions\n");
	# Use cache if available.
	my $oldHash = $RDF::Pipeline::HashTemplateName::nameToHashCache{$template}->{$name} || "";
	#
	# On the first iteration, the mere existence of $oldHash means
	# that we found it and can return it immediately.
	return $oldHash if $oldHash && 1 == $nCollisions;
	&Warn("HashTemplateName passed first check\n");
	#
	# Either this is not the first iteration (so $name ne $originalName)
	# or we didn't find $name in the cache.  If $name was found
	# in the cache *after* the first iteration, then it indicates
	# another collision, because $name is not the same as $originalName
	# and its hash ($oldHash) is already in the cache, so its slot 
	# is already taken (for $name).  For example, $originalName
	# might be foo, and $name might be foo44 (if 44 had been the
	# hash of foo), and coicidentally foo44 already had a hash ($oldHash)
	# registered in the cache, so we cannot use $oldHash for $originalName.
	if ($oldHash) {
		&Warn("HashTemplateName collision1 detected in cache\n");
		# Collision.  Append the hash and try again.
		$name .= $oldHash;
		next;
		}
	#
	# Didn't find it in the cache.  Compute the hash.
	my $hash = &SafeBase64Hash($name);
	# Again, if it is in the cache then it must be a collision.
	my $oldName = $RDF::Pipeline::HashTemplateName::hashToNameCache{$template}->{$hash} || "";
	if ($oldName) {
		&Warn("HashTemplateName collision2 detected in cache\n");
		# Collision.  Append the hash and try again.
		$name .= $hash;
		next;
		}
	# Sanity check -- this should never happen, otherwise
	# we would have found it in the cache when we first checked:
	confess "[INTERNAL ERROR] Algorithm error! Found name in memory hash cache: $name"
		if $oldName eq $originalName;
	# Need to check $hashMapFile.  There are three possible outcomes:
	# 1. Empty file ($hash is unique) 2. Found. 3. Collision.
	my $hashMapFile = $template;
	($hashMapFile =~ s/\{\}/$hash/g) or confess "[INTERNAL ERROR] hashMapFile template lacks {}: $template";
	&MakeParentDirs($hashMapFile);
	# Got this flock code pattern from
	# http://www.stonehenge.com/merlyn/UnixReview/col23.html
	# See also http://docstore.mik.ua/orelly/perl/cookbook/ch07_12.htm
	&Warn("HashTemplateName locking $hashMapFile\n");
	sysopen(my $fh, $hashMapFile, O_RDWR|O_CREAT) 
		or confess "[ERROR] Cannot open $hashMapFile: $!";
	&Warn("Locking...\n");
	flock $fh, 2;			# LOCK_EX -- exclusive lock
	&Warn("Got lock!!!!!!\n");
	sleep 5;
	# I could not figure out from the documentation whether
	# there is read-ahead buffering done when the file is opened
	# using sysopen.   So AFAIK this code could be unsafe.  See:
	# http://www.perlmonks.org/?node_id=1082675
	my $line = <$fh> || "";
	my $originalLine = $line;
	chomp $line;
	$line =~ s/^\s+//;	# Strip leading spaces
	if (!$line) {
		&Warn("HashTemplateName hash is new: $hash\n");
		# $hashMapFile was empty: $hash is unique (no collision).
		# Cache it:
		$RDF::Pipeline::HashTemplateName::nameToHashCache{$template}->{$originalName} = $hash;
		$RDF::Pipeline::HashTemplateName::hashToNameCache{$template}->{$hash} = $originalName;
		# Write it, release the lock and be done.
		seek $fh, 0, 0;
		truncate $fh, 0;
		print $fh "$hash $originalName\n";
		close $fh or die;	# Releases lock
		my $nc = $nCollisions - 1;
		&Warn("[WARNING] Hash collision $nc for $originalName\n") if $nc;
		return $hash;
		}
	# $hashMapFile contains something.  See if it matches.
	# Hash must not contain spaces, but $oldName could:
	($oldHash, $oldName) = split(/ /, $line, 2);
	$oldName = "" if !defined($oldName);
	# Strip leading/trailing whitespace:
	$oldName =~ s/\A\s+//;
	$oldName =~ s/\s+\Z//;
	if (!$oldHash || $oldName eq "" || $oldHash ne $hash) {
		close $fh;	# Release lock before dying
		confess "[INTERNAL ERROR] Corrupt hashMapFile: $hashMapFile!  Contents: $originalLine";
		}
	# Cache what we found, whether it matches or not:
	$RDF::Pipeline::HashTemplateName::nameToHashCache{$template}->{$oldName} = $hash;
	$RDF::Pipeline::HashTemplateName::hashToNameCache{$template}->{$hash} = $oldName;
	close $fh or die;	# Releases lock
	&Warn("HashTemplateName Lock released\n");
	return $hash if ($oldName eq $originalName);
	&Warn("HashTemplateName collision3\n");
	#
	# Collision.  Try again.
	$name .= $hash;
	}
confess "[INTERNAL ERROR] Should never get here!";
return "";
}

############# NameToLmFile #############
# Convert $nameType + $name to a LM file path.
# The combination must be unique -- a composite key.
# $nameType will be either $URI, $FILE or a nodeType (which can
# never be either $URI or $FILE).
sub NameToLmFile
{
my $nameType = shift || confess;
my $name = shift || die;
# Use cached LM file path if available:
my $lmFile = $RDF::Pipeline::NameToLmFile::lmFile{$nameType}->{$name} || "";
if (!$lmFile) {
	my $t = uri_escape($nameType);
	my $f = uri_escape($name);
	$lmFile = "$basePath/lm/$t/$f";
	$RDF::Pipeline::NameToLmFile::lmFile{$nameType}->{$name} = $lmFile;
	}
return $lmFile;
}

############# SaveLMs ##############
# Save Last-Modified times of $thisName and its inputs (actually its dependsOns).
# Called as: &SaveLMs($nameType, $thisName, $thisLM, %depLMs);
# Actually, this can be used to save/load any lines of data, using
# $nameType and $thisName as the composite key.
# The lines are given as strings with no newline at the ends.
sub SaveLMs
{
@_ >= 3 || die;
my ($nameType, $thisName, $thisLM, @depLMs) = @_;
# Make sure the data to be saved does not contain newlines:
grep { die if m/\n/s; 0} @depLMs;
my $f = &NameToLmFile($nameType, $thisName);
my $cThisUri = "# $nameType $thisName";
my $s = join("\n", $cThisUri, $thisLM, @depLMs) . "\n";
&Warn("SaveLMs($nameType, $thisName, $thisLM, ...) to file: $f\n", $DEBUG_DETAILS);
&Warn("... $cThisUri\n", $DEBUG_DETAILS);
foreach my $line ("# $nameType $thisName", @depLMs) {
	&Warn("... $line\n", $DEBUG_DETAILS);
	}
&WriteFile($f, $s);
}

############# LookupLMs ##############
# Lookup LM times of $thisName and its inputs (actually its dependsOns).
# Called as: my ($thisLM, %depLMs) = &LookupLMs($nameType, $thisName);
# Actually, this can be used to save/load any lines of data, using
# $nameType and $thisName as the composite key.
sub LookupLMs
{
@_ == 2 || die;
my ($nameType, $thisName) = @_;
my $f = &NameToLmFile($nameType, $thisName);
open(my $fh, $f) or return ("", ());
my ($cThisUri, $thisLM, @depLMs) = map {chomp; $_} <$fh>;
close($fh) || die;
&Warn("LookupLMs($nameType, $thisName) from file: $f\n", $DEBUG_DETAILS);
&Warn("... $cThisUri\n", $DEBUG_DETAILS);
$cThisUri =~ m/\A\#/ or die;
foreach my $line ($thisLM, @depLMs) {
	&Warn("... $line\n", $DEBUG_DETAILS);
	}
return($thisLM, @depLMs);
}

############# SaveLMHeaders ##############
# Save LM and Last-Modified and ETag headers for a serCache.
sub SaveLMHeaders
{
@_ == 4 || die;
my ($serCache, $serCacheLM, $serCacheLMHeader, $serCacheETagHeader) = @_;
&SaveLMs($FILE, $serCache, $serCacheLM, 
	"Last-Modified: $serCacheLMHeader", 
	"ETag: $serCacheETagHeader");
}

############# LookupLMHeaders ##############
# Lookup LM and Last-Modified and ETag headers for a serCache.
sub LookupLMHeaders
{
@_ == 1 || die;
my ($serCache) = @_;
my ($serCacheLM, $serCacheLMHeader, $serCacheETagHeader) = 
	&LookupLMs($FILE, $serCache);
$serCacheLM ||= "";
$serCacheLMHeader ||= "";
$serCacheETagHeader ||= "";
$serCacheLMHeader =~ s/^Last\-Modified\:\s*//;
$serCacheETagHeader =~ s/^ETag\:\s*//;
return ($serCacheLM, $serCacheLMHeader, $serCacheETagHeader);
}

############# FileExists ##############
sub FileExists
{
@_ == 2 || die;
my ($f, $hostRoot) = @_;
$hostRoot = $hostRoot;  # Avoid unused var warning
return -e $f;
}

############# RegisterWrappers ##############
sub RegisterWrappers
{
@_ == 1 || die;
my ($nm) = @_;
# TODO: Wrapper registration should be done differently so that the 
# framework can verify that all required properties have been set for
# a new node type, and issue a warning if not.  Somehow, the framework
# needs to know what node types are being registered.
&FileNodeRegister($nm);
&RDF::Pipeline::ExampleHtmlNode::ExampleHtmlNodeRegister($nm);
&RDF::Pipeline::GraphNode::GraphNodeRegister($nm);
}

############# FileNodeRegister ##############
sub FileNodeRegister
{
@_ == 1 || die;
my ($nm) = @_;
$nm->{value}->{FileNode} = {};
$nm->{value}->{FileNode}->{fSerializer} = "";
$nm->{value}->{FileNode}->{fDeserializer} = "";
$nm->{value}->{FileNode}->{fUriToNativeName} = \&UriToPath;
$nm->{value}->{FileNode}->{fRunUpdater} = \&FileNodeRunUpdater;
$nm->{value}->{FileNode}->{fRunParametersFilter} = \&FileNodeRunParametersFilter;
$nm->{value}->{FileNode}->{fExists} = \&FileExists;
$nm->{value}->{FileNode}->{defaultContentType} = "text/plain";
}

############# FileNodeRunParametersFilter ##############
# Run the parametersFilter, returning a listRef of input queryStrings.
sub FileNodeRunParametersFilter
{
@_ == 6 || die;
my ($nm, $thisUri, $parametersFilter, $pInputUris, 
	$latestQuery, $pOutputQueries) = @_;
# Avoid unused var warning:
($nm, $thisUri, $parametersFilter, $pInputUris, 
	$latestQuery, $pOutputQueries) = 
($nm, $thisUri, $parametersFilter, $pInputUris, 
	$latestQuery, $pOutputQueries);
&Warn("FileNodeRunParametersFilter(nm, $thisUri, $parametersFilter, ..., $latestQuery, ...) called.\n", $DEBUG_DETAILS);
$parametersFilter or die;
$parametersFilter = &NodeAbsPath($parametersFilter) if $parametersFilter;
# TODO: Move this warning to when the metadata is loaded?
if (!-x $parametersFilter) {
	die "ERROR: $thisUri parametersFilter $parametersFilter is not executable by web server!";
	}
my $qInputUris = join(" ", map {quotemeta($_)} @{$pInputUris});
&Warn("qInputUris: $qInputUris\n", $DEBUG_DETAILS);
my $qLatestQuery = quotemeta($latestQuery);
my $exportqs = "export QUERY_STRING=$qLatestQuery";
my $qss = quotemeta(join(" ", @{$pOutputQueries}));
my $exportqss = "export QUERY_STRINGS=$qss";
my $tmp = "$tmpDir/parametersFilterOut" . &GenerateNewLM() . ".txt";
my $stderr = $nm->{value}->{$thisUri}->{stderr};
# Make sure parent dirs exist for $stderr and $tmp:
&MakeParentDirs($stderr, $tmp);
# Ensure no unsafe chars before invoking $cmd:
my $qThisUri = quotemeta($thisUri);
my $qTmp = quotemeta($tmp);
my $qUpdater = quotemeta($parametersFilter);
my $qStderr = quotemeta($stderr);
my $useStdout = 1;
#### TODO QUERY:
my $cmd = "( cd '$nodeBasePath' ; export THIS_URI=$qThisUri ; $exportqs ; $exportqss ; $qUpdater $qInputUris > $qTmp 2> $qStderr )";
####
&Warn("cmd: $cmd\n", $DEBUG_DETAILS);
my $result = (system($cmd) >> 8);
my $saveError = $?;
&Warn("FileNodeRunParametersFilter: Updater returned " . ($result ? "error code:" : "success:") . " $result.\n", $DEBUG_DETAILS);
if (-s $stderr) {
	&Warn("FileNodeRunParametersFilter: Updater stderr" . ($useStdout ? "" : " and stdout") . ":\n[[\n", $DEBUG_DETAILS);
	&Warn(&ReadFile("<$stderr"), $DEBUG_DETAILS);
	&Warn("]]\n", $DEBUG_DETAILS);
	}
if ($result) {
	&Warn("FileNodeRunParametersFilter: parametersFilter ERROR: $saveError\n");
	# return { map {"$_?$latestQuery"} @{pInputUris} };
	die;
	}
open(my $fh, "<$tmp") || die;
my $pInputQueries = { map {chomp; split(/\?/, $_, 2)} <$fh> };
close($fh) || die;
unlink $tmp || die;
my $nq = scalar(keys %{$pInputQueries});
my $ni = scalar(@{$pInputUris});
$nq == $ni or die "ERROR: $thisUri parametersFilter $parametersFilter returned $nq query strings for $ni inputs.\n";
&Warn("FileNodeRunParametersFilter returning InputQueries:\n", $DEBUG_DETAILS);
foreach my $inUri (sort keys %{$pInputQueries}) {
	my $q = $pInputQueries->{$inUri};
	&Warn("  $inUri?$q\n", $DEBUG_DETAILS);
	}
return $pInputQueries;
}

############# LatestRunParametersFilter ##############
# This is the default way of filtering parameters.  It simply passes
# the latest queryString to each input.
sub LatestRunParametersFilter 
{
@_ == 6 || die;
my ($nm, $thisUri, $parametersFilter, $pInputUris, 
	$latestQuery, $pOutputQueries) = @_;
# Avoid unused var warning:
($nm, $thisUri, $parametersFilter, $pInputUris, 
	$latestQuery, $pOutputQueries) = 
($nm, $thisUri, $parametersFilter, $pInputUris, 
	$latestQuery, $pOutputQueries);
&Warn("LatestRunParametersFilter(nm, $thisUri, $parametersFilter, [ @$pInputUris ], $latestQuery, [ @$pOutputQueries ]) called.\n", $DEBUG_DETAILS);
return { map {($_, $latestQuery)} @{$pInputUris} };
}

############# FileNodeRunUpdater ##############
# Run the updater.
# If there is no updater (i.e., static state) then we must generate
# an LM from the state.
sub FileNodeRunUpdater
{
@_ == 9 || die;
my ($nm, $thisUri, $updater, $state, $thisInputs, $thisParameters, 
	$oldThisLM, $callerUri, $callerLM) = @_;
# Avoid unused var warning:
($nm, $thisUri, $updater, $state, $thisInputs, $thisParameters, 
	$oldThisLM, $callerUri, $callerLM) = @_;
($nm, $thisUri, $updater, $state, $thisInputs, $thisParameters, 
	$oldThisLM, $callerUri, $callerLM) = @_;
&Warn("FileNodeRunUpdater(nm, $thisUri, $updater, $state, ...) called.\n", $DEBUG_DETAILS);
return &TimeToLM(&MTime($state)) if !$updater;
$state || die;
$state = &NodeAbsPath($state);
$updater = &NodeAbsPath($updater);
&Warn("Abs state: $state  Abs updater: $updater\n", $DEBUG_DETAILS);
# TODO: Move this warning to when the metadata is loaded?
if (!-x $updater) {
	die "ERROR: $thisUri updater $updater is not executable by web server!";
	}
# The FileNode updater args are local filenames for all
# inputs and parameters.
my $inputFiles = join(" ", map {quotemeta($_)} 
	@{$nm->{list}->{$thisUri}->{inputCaches}});
&Warn("inputFiles: $inputFiles\n", $DEBUG_DETAILS);
my $parameterFiles = join(" ", map {quotemeta($_)} 
	@{$nm->{list}->{$thisUri}->{parameterCaches}});
&Warn("parameterFiles: $parameterFiles\n", $DEBUG_DETAILS);
my $ipFiles = "$inputFiles $parameterFiles";
#### TODO: Move this code out of this function and pass $latestQuery
#### as a parameter to FileNodeRunUpdater.
#### TODO QUERY:
my $thisVHash = $nm->{value}->{$thisUri} or die;
my $parametersFile = $thisVHash->{parametersFile} or die;
my ($lm, $latestQuery, %requesterQueries) = 
	&LookupLMs($FILE, $parametersFile);
$lm = $lm;				# Avoid unused var warning
my $qLatestQuery = quotemeta($latestQuery);
my $exportqs = "export QUERY_STRING=$qLatestQuery";
# my $qss = quotemeta(&BuildQueryString(%requesterQueries));
my $qss = quotemeta(join(" ", sort values %requesterQueries));
my $exportqss = "export QUERY_STRINGS=$qss";
####
my $stderr = $nm->{value}->{$thisUri}->{stderr};
# Make sure parent dirs exist for $stderr and $state:
&MakeParentDirs($stderr, $state);
# Ensure no unsafe chars before invoking $cmd:
my $qThisUri = quotemeta($thisUri);
my $qState = quotemeta($state);
my $qUpdater = quotemeta($updater);
my $qStderr = quotemeta($stderr);
my $useStdout = 0;
my $stateOriginal = $nm->{value}->{$thisUri}->{stateOriginal} || "";
&Warn("stateOriginal: $stateOriginal\n", $DEBUG_DETAILS);
$useStdout = 1 if $updater && !$stateOriginal;
my $cmd = "( cd '$nodeBasePath' ; export THIS_URI=$qThisUri ; $qUpdater $qState $ipFiles > $qStderr 2>&1 )";
$cmd =    "( cd '$nodeBasePath' ; export THIS_URI=$qThisUri ; $qUpdater         $ipFiles > $qState 2> $qStderr )"
	if $useStdout;
#### TODO QUERY:
$cmd = "( cd '$nodeBasePath' ; export THIS_URI=$qThisUri ; $exportqs ; $exportqss ; $qUpdater $qState $ipFiles > $qStderr 2>&1 )";
$cmd = "( cd '$nodeBasePath' ; export THIS_URI=$qThisUri ; $exportqs ; $exportqss ; $qUpdater         $ipFiles > $qState 2> $qStderr )"
	if $useStdout;
####
&Warn("cmd: $cmd\n", $DEBUG_DETAILS);
my $result = (system($cmd) >> 8);
my $saveError = $?;
&Warn("FileNodeRunUpdater: Updater returned " . ($result ? "error code:" : "success:") . " $result.\n", $DEBUG_DETAILS);
if (-s $stderr) {
	&Warn("FileNodeRunUpdater: Updater stderr" . ($useStdout ? "" : " and stdout") . ":\n[[\n", $DEBUG_DETAILS);
	&Warn(&ReadFile("<$stderr"), $DEBUG_DETAILS);
	&Warn("]]\n", $DEBUG_DETAILS);
	}
# unlink $stderr;
if ($result) {
	&Warn("FileNodeRunUpdater: UPDATER ERROR: $saveError\n");
	return "";
	}
my $newLM = &GenerateNewLM();
&Warn("FileNodeRunUpdater returning newLM: $newLM\n", $DEBUG_DETAILS);
return $newLM;
}

############# GenerateNewLM ##############
# Generate a new LM, based on the current time, that is guaranteed unique
# on this server even if this function is called faster than the 
# Time::HiRes clock resolution.  Furthermore, within the same thread
# it is guaranteed to increase monotonically (assuming the Time::HiRes
# clock increases monotonically).  This is done by
# appending a counter to the lower order digits of the current time.
# The counter is stored in $lmCounterFile and flock is used to
# ensure that it is accessed by only one thread at a time.
# As of 23-Jan-2012 on dbooth's laptop &GenerateNewLM() took
# about 200-300 microseconds per call, so the counter will always 
# be 1 unless this is run on a machine that is much faster or that
# has substantially lower clock resolution.
#
# TODO: Need to test the locking (flock) aspect of this code.  The other 
# logic of this function has already been tested.
sub GenerateNewLM
{
# Format time to avoid losing digits when serializing:
my $newTime = &FormatTime(scalar(Time::HiRes::gettimeofday()));
my $MAGIC = "# Hi-Res Last Modified (LM) Counter\n";
&MakeParentDirs($lmCounterFile);
# Got this flock code pattern from
# http://www.stonehenge.com/merlyn/UnixReview/col23.html
# See also http://docstore.mik.ua/orelly/perl/cookbook/ch07_12.htm
# open(my $fh, "+<$lmCounterFile") or croak "Cannot open $lmCounterFile: $!";
sysopen(my $fh, $lmCounterFile, O_RDWR|O_CREAT) 
	or confess "Cannot open $lmCounterFile: $!";
flock $fh, 2;
my ($oldTime, $counter) = ($newTime, 0);
my $magic = <$fh>;
# Remember any warning, to avoid other I/O while $lmCounterFile is locked:
my $warning = "";	
if (defined($magic)) {
	$warning = "Corrupt lmCounter file (bad magic string): $lmCounterFile\n" if $magic ne $MAGIC;
	chomp( $oldTime = <$fh> );
	chomp( $counter = <$fh> );
	if (!$counter || !$oldTime || $oldTime>$newTime || $counter<=0) {
		$warning .= "Corrupt $lmCounterFile or non-monotonic clock\n";
		($oldTime, $counter) = ($newTime, 0);
		}
	}
$counter = 0 if $newTime > $oldTime;	# Reset counter whenever time changes
$counter++;
seek $fh, 0, 0;
truncate $fh, 0;
print $fh $MAGIC;
print $fh "$newTime\n";
print $fh "$counter\n";
close $fh;	# Release flock
&Warn("[WARNING] $warning") if $warning;
return &TimeToLM($newTime, $counter);
}

############# MTimeAndInode ##############
# Return the $mtime (modification time) and inode of a file.
sub MTimeAndInode
{
@_ == 1 || die;
my $f = shift;
my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
	      $atime,$mtime,$ctime,$blksize,$blocks)
		  = stat($f);
# Avoid unused var warning:
($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
	      $atime,$mtime,$ctime,$blksize,$blocks)
	= ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
	      $atime,$mtime,$ctime,$blksize,$blocks);
# warn "MTime($f): $mtime\n";
return ($mtime, $ino);
}

############# MTime ##############
# Return the $mtime (modification time) of a file.
sub MTime
{
return (&MTimeAndInode(@_))[0];
}

############## QuickName ##############
# Generate a relative path or filename based on the given URI.
sub QuickName
{
my $t = shift;
$t =~ s|$nodeBaseUriPattern\/||;	# Simplify if it's local
$t = uri_escape($t);
return $t;
}

########## NodeAbsUri ############
# Converts (possibly relative) URI to absolute URI, using $nodeBaseUri.
sub NodeAbsUri
{
my $uri = shift;
##### TODO: Should this pattern be more general than just http:?
if ($uri !~ m/\Ahttp(s?)\:/ && $uri !~ m/\Afile\:/) {
	# Relative URI
	$uri =~ s|\A\/||;	# Chop leading / if any
	$uri = "$nodeBaseUri/$uri";
	}
return $uri;
}

########## AbsUri ############
# Converts (possibly relative) URI to absolute URI, using $baseUri.
sub AbsUri
{
my $uri = shift;
##### TODO: Should this pattern be more general than just http:?
if ($uri !~ m/\Ahttp(s?)\:/) {
	# Relative URI
	$uri =~ s|\A\/||;	# Chop leading / if any
	$uri = "$baseUri/$uri";
	}
return $uri;
}

########## UriToPath ############
# Converts (possibly relative) URI to absolute file path (if local) 
# or returns "".   Extra parameters ($baseUri and $hostRoot) are ignored
# and globals $baseUriPattern and $basePath are used instead.
sub UriToPath
{
my $uri = shift;
### Ignore these parameters and use globals $baseUriPattern and $basePath:
my $path = &AbsUri($uri);
if ($path =~ s/\A$baseUriPattern\b/$basePath/e) {
	return $path;
	}
return "";
}

########## NodeAbsPath ############
# Converts (possibly relative) file path to absolute path,
# using $nodeBasePath.
sub NodeAbsPath
{
my $path = shift;
if ($path !~ m|\A\/|) {
	# Relative path
	$path = "$nodeBasePath/$path";
	}
return $path;
}

########## AbsPath ############
# Converts (possibly relative) file path to absolute path,
# using $basePath.
sub AbsPath
{
my $path = shift;
if ($path !~ m|\A\/|) {
	# Relative path
	$path = "$basePath/$path";
	}
return $path;
}

########## PathToUri ############
# Converts (possibly relative) file path to absolute URI (if local) 
# or returns "".
sub PathToUri
{
my $path = shift;
my $uri = &AbsPath($path);
if ($uri =~ s/\A$basePathPattern\b/$baseUri/e) {
	return $uri;
	}
return "";
}

########## PrintLog ############
sub PrintLog
{
open(my $fh, ">>$logFile") || die;
# print($fh, @_) or die;
print $fh @_ or die;
# print $fh @_;
close($fh) || die;
return 1;
}

########## CallStackDepth ###########
sub CallStackDepth
{
my $depth = 0;
while (1) {
	my ($package) = caller($depth);
	last if !$package;
	last if $package ne 'RDF::Pipeline';
	$depth++;
	}
return $depth;
}

########## Warn ############
# Log a warning if the current $debug >= $level for this warning.
# This will go to the apache error log: /var/log/apache2/error.log
# and also to $logFile .
sub Warn
{
die if @_ < 1 || @_ > 2;
my ($msg, $level) = @_;
my $maxRecursion = 30;
my $depth = $debugStackDepth + &CallStackDepth() -2;
confess "PANIC!!!  Deep recursion > $maxRecursion! debug $debug \n Maybe a cycle in the pipeline graph?\n " if $depth >= $maxRecursion;
return 1 if defined($level) && $debug < $level;
my $indent = $depth *2;
# Additional indent like &Warn("  One\nTwo\n") will be applied to
# all lines in the given string also, producing:
#     One
#     Two
my $moreSpaces = "";
$moreSpaces = $1 if $msg =~ s/^(\s+)//;
my $spaces = (" " x $indent) . $moreSpaces;
$msg =~ s/^/$spaces/mg;
&PrintLog($msg);
warn "debug not defined!\n" if !defined($debug);
warn "configLastModified not defined!\n" if !defined($configLastModified);
print STDERR $msg if !defined($level) || $debug >= $level;
return 1;
}

########## MakeParentDirs ############
# Ensure that parent directories exist before creating these files.
# Optionally, directories that have already been created are remembered, so
# we won't waste time trying to create them again.
sub MakeParentDirs
{
my $optionRemember = 0;
foreach my $f (@_) {
	next if $MakeParentDirs::fileSeen{$f} && $optionRemember;
	$MakeParentDirs::fileSeen{$f} = 1;
	my $fDir = "";
	$fDir = $1 if $f =~ m|\A(.*)\/|;
	next if $MakeParentDirs::dirSeen{$fDir} && $optionRemember;
	$MakeParentDirs::dirSeen{$fDir} = 1;
	next if $fDir eq "";	# Hit the root?
	make_path($fDir);
	-d $fDir || die "ERROR: Failed to create directory: $fDir\n ";
	}
}

########## IsSameServer ############
# Is $thisUri on the same server as $baseUri?
sub IsSameServer
{
@_ == 2 or die;
my ($baseUri, $thisUri) = @_;
return 0 if !$baseUri or !$thisUri;
$baseUri =~ m/\A[^\/]*/;
my $baseServer = $& || "";
$thisUri =~ m/\A[^\/]*/;
my $thisServer = $& || "";
my $isSame = ($baseServer eq $thisServer);
# &Warn("IsSameServer($baseUri , $thisUri): $isSame\n", $DEBUG_DETAILS);
return $isSame;
}

########## IsSameType ############
# Are $thisType and $depType both set and their {stateType}s the same?  
sub IsSameType
{
@_ == 3 or die;
my ($nm, $thisType, $depType) = @_;
return 0 if !$thisType or !$depType;
return 1 if $thisType eq $depType;
my $thisStateType = $nm->{value}->{$thisType}->{stateType} || $thisType;
my $depStateType  = $nm->{value}->{$depType}->{stateType}  || $depType;
return 1 if $thisStateType eq $depStateType;
return 0;
}

########## FormatTime ############
# Turn a floating Time::HiRes time into a string.
# The string is padded with leading zeros for easy string comparison,
# ensuring that $a lt $b iff $a < $b.
# An empty string "" will be returned if the time is 0.
sub FormatTime
{
@_ == 1 or die;
my ($time) = @_;
return "" if !$time || $time == 0;
# Enough digits to work through year 2286:
my $lm = sprintf("%010.6f", $time);
length($lm) == 10+1+6 or confess "Too many digits in time!";
return $lm;
}

########## FormatCounter ############
# Format a counter for use in an LM string.
# The counter becomes the lowest order digits.
# The string is padded with leading zeros for easy string comparison,
# ensuring that $a lt $b iff $a < $b.
sub FormatCounter
{
@_ == 1 or die;
my ($counter) = @_;
$counter = 0 if !$counter;
my $counterWidth = 6;
my $sCounter = sprintf("%0$counterWidth" . "d", $counter);
confess "Need more than $counterWidth digits in counter!"
	if length($sCounter) > $counterWidth;
return $sCounter;
}

########## TimeToLM ############
# Turn a floating Time::HiRes time (and optional counter) into an LM string, 
# for use in headers, etc.  The counter becomes the lowest order digits.
# The string is padded with leading zeros for easy string comparison,
# ensuring that $a lt $b iff $a < $b.
# An empty string "" will be returned if the time is 0.
# As generated, these are monotonic.  But in general the system does
# not require LMs to be monotonic, because they could be checksums.
# The only guarantee that the system requires is that they change
# if a node output has changed.
sub TimeToLM
{
@_ == 1 || @_ == 2 or die;
my ($time, $counter) = @_;
$counter = 0 if !$counter;
return "" if !$time;
return &FormatTime($time) . &FormatCounter($counter);
}

########## LMToHeaders ############
# Turn LM (high-res last-modified) into Last-Modified and ETag headers.
# The ETag header that is generated is formatted assuming that it is
# a strong ETag, i.e., it will not have a preceding "W/".
sub LMToHeaders
{
@_ == 1 or die;
# $lm should actually be a float represented as a string -- not a 
# float -- to ease comparison and avoid accidentally dropping decimal places.
my ($lm) = @_;
return("", "") if !$lm;
my $lmHeader = time2str($lm);
# ETag syntax:
# http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.11
# and quoted-string at the end of sec 2.2:
# http://www.w3.org/Protocols/rfc2616/rfc2616-sec2.html#sec2.2
my $eTagHeader = "\"LM$lm\"";
return($lmHeader, $eTagHeader);
}

########## HeadersToLM ############
# Turn Last-Modified and ETag headers into LM (high-res last-modified).
# This is round-trippable if it was generated by LMToHeaders.  
# It is a a one-way operation (i.e., not round-trippable) if something
# else generated the ETag.
# If the server didn't send either a Last-Modified or an ETag, then
# we cannot cache the result at all, so we'll generate and return
# a (fake) unique LM using &GenerateNewLM().
sub HeadersToLM
{
@_ == 2 or die;
my ($lmHeader, $eTagHeader) = @_;
my $lm = "";
$lm = &TimeToLM(str2time($lmHeader)) if $lmHeader;
# ETag syntax:
# http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.11
# and quoted-string at the end of sec 2.2:
# http://www.w3.org/Protocols/rfc2616/rfc2616-sec2.html#sec2.2
if ($eTagHeader) {
  if ($eTagHeader =~ m|\A(W\/)?\"(.*)\"\Z|) {
    my $etag = $2;
    # Format generated by LMToHeaders:
    # LM1328199534.092006000001
    if ($etag =~ m/\A(LM)((\d+)\.(\d+))\Z/) {
      $lm = $2;
      }
    }
  else {
    &Warn("WARNING: Bad ETag header received: $eTagHeader ");
    }
  }
$lm = &GenerateNewLM() if !$lm;
&Warn("HeadersToLM($lmHeader, $eTagHeader) returning LM: $lm\n", $DEBUG_DETAILS);
return $lm;
}

############## PrintNodeMetadata ################
sub PrintNodeMetadata
{
my $nm = shift || die;
my $nmv = $nm->{value} || {};
my $nml = $nm->{list}  || {};
my $nmh = $nm->{hash}  || {};
my $nmm = $nm->{multi} || {};
&PrintLog("Node Metadata:\n") if $debug;
my %allSubjects = (%{$nmv}, %{$nml}, %{$nmh}, %{$nmm});
foreach my $s (sort keys %allSubjects) {
	last if !$debug;
	my %allPredicates = ();
	%allPredicates = (%allPredicates, %{$nmv->{$s}}) if $nmv->{$s};
	%allPredicates = (%allPredicates, %{$nml->{$s}}) if $nml->{$s};
	%allPredicates = (%allPredicates, %{$nmh->{$s}}) if $nmh->{$s};
	%allPredicates = (%allPredicates, %{$nmm->{$s}}) if $nmm->{$s};
	foreach my $p (sort keys %allPredicates) {
		if ($nmv->{$s} && $nmv->{$s}->{$p}) {
		  my $v = $nmv->{$s}->{$p};
		  &PrintLog("  $s -> $p -> $v\n");
		  }
		if ($nml->{$s} && $nml->{$s}->{$p}) {
		  my @vList = @{$nml->{$s}->{$p}};
		  my $vl = join(" ", @vList);
		  &PrintLog("  $s -> $p -> ($vl)\n");
		  }
		if ($nmh->{$s} && $nmh->{$s}->{$p}) {
		  my %vHash = %{$nmh->{$s}->{$p}};
		  my @vHash = map {($_,$vHash{$_})} sort keys %vHash;
		  # @vHash = map {defined($_) ? $_ : '*undef*'} @vHash;
		  my $vh = join(" ", @vHash);
		  &PrintLog("  $s -> $p -> {$vh}\n");
		  }
		if ($nmm->{$s} && $nmm->{$s}->{$p}) {
		  my %vHash = %{$nmm->{$s}->{$p}};
		  my @vHash = sort keys %vHash;
		  grep { 
			my $v=$vHash{$_}; 
			if ($v != 1) { 
			  &Warn("BAD nmm value \$vHash{$_}: $v\n");
			  die;
			  } 
			} @vHash;
		  # @vHash = map {defined($_) ? $_ : '*undef*'} @vHash;
		  my $vh = join(" ", @vHash);
		  &PrintLog("  $s -> $p -> [$vh]\n");
		  }
		}
	}
}

##### DO NOT DELETE THE FOLLOWING TWO LINES!  #####
1;
__END__

=head1 NAME

RDF::Pipeline - Perl extension for blah blah blah

=head1 SYNOPSIS

  use RDF::Pipeline;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for RDF::Pipeline, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

David Booth <lt>david@dbooth.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2011 & 2012 David Booth <david@dbooth.org>
See license information at http://code.google.com/p/rdf-pipeline/ 

=cut

