#! /usr/bin/perl -w

# Run a test of an RDF Pipeline by using curl to invoke a URL, 
# concatenating the output and the apache access and error logs 
# to the $RDF_PIPELINE_WWW_DIR/test directory.
# Because the results are concatenated, a single test may run
# this script more than once.  
#
# Usage: 
#	pipeline-request.perl [GET/HEAD] URL
#
# where URL is the pipeline URL to invoke and GET or HEAD is the HTTP
# method to use.  The method defaults to GET if not specified.
#
# Example: 
#	pipeline-request.perl HEAD http://localhost/node/addone

use strict;

my $sleepSeconds = 0;	# Time to wait for Apache to finish writing log files.

my $wwwDir = $ENV{'RDF_PIPELINE_WWW_DIR'} or &EnvNotSet('RDF_PIPELINE_WWW_DIR');
my $devDir = $ENV{'RDF_PIPELINE_DEV_DIR'} or &EnvNotSet('RDF_PIPELINE_DEV_DIR');
my $moduleDir = "$devDir/RDF-Pipeline";
# chdir("$moduleDir/t") or die "ERROR: Could not chdir('$moduleDir/t')\n";
# my $testsDir = "$moduleDir/t/tests";
# chdir($testsDir) or die "ERROR: Could not chdir('$testsDir')\n";

###### Configure these paths as needed:
my $apacheError = "/var/log/apache2/error.log";
my $apacheAccess = "/var/log/apache2/access.log";
my $stripDates = "$moduleDir/t/helpers/stripdates.perl";
my $filterLog = "$moduleDir/t/helpers/filterlog.perl";

# Get command line arguments:
my $method = 'GET';
$method = uc(shift @ARGV) if @ARGV > 1;
@ARGV == 1 or die "Usage: $0 [GET/HEAD] URL\n";
my $url = shift @ARGV;
$method eq "GET" || $method eq "HEAD" or die "Usage: $0 [GET/HEAD] URL\n";
$url =~ m/^http(s?)\:/ or die "Usage: $0 [GET/HEAD] URL\n";

-x $stripDates or die "ERROR: Not found or not executable: $stripDates\n";
-x $filterLog or die "ERROR: Not found or not executable: $filterLog\n";

my $apacheErrorStart = 1;	# Starting line
$apacheErrorStart = `wc -l < '$apacheError'` + 1 if -e $apacheError;
# warn "apacheError lines: $apacheErrorStart\n";
my $apacheAccessStart = 1;	# Starting line
$apacheAccessStart = `wc -l < '$apacheAccess'` + 1 if -e $apacheAccess;
# warn "apacheAccess lines: $apacheAccessStart\n";

-d "$wwwDir/test" || mkdir("$wwwDir/test") or die;

# Sleep is used here to ensure that apache has had time to write
# the log files.
my $curlOption = $method eq "HEAD" ? "-I" : "-i";
my $curlCmd = "curl $curlOption -s '$url' | '$stripDates' >> '$wwwDir/test/testout' ; sleep $sleepSeconds";
# warn "curlCmd: $curlCmd\n";
my $curlResult = system($curlCmd);
die "ERROR: curl failed: $curlCmd\n" if $curlResult;

# [Wed Jan 25 15:33:03 2012] [notice] Apache/2.2.14 (Ubuntu) DAV/2 mod_perl/2.0.4 Perl/v5.10.1 configured -- resuming normal operations
my $filterErr = "grep -v '\\[notice\\] *Apache' | '$stripDates'";
my $errCmd = "tail -n +'$apacheErrorStart' '$apacheError' | $filterErr >> '$wwwDir/test/apacheError.log'";
# warn "errCmd: $errCmd\n";
my $errResult = system($errCmd);
die "ERROR: Failed to copy Apache error log: $errCmd\n" if $errResult;

my $logCmd = "tail -n +'$apacheAccessStart' '$apacheAccess' | '$filterLog' | sort >> '$wwwDir/test/apacheAccess.log'";
# warn "logCmd: $logCmd\n";
my $logResult = system($logCmd);
die "ERROR: Failed to copy Apache access log: $logCmd\n" if $logResult;

my $separator = "-" x 70;
foreach my $f (qw(testout apacheError.log apacheAccess.log)) {
	!system("echo '$separator' >> '$wwwDir/test/$f'") or die;
	}
exit 0;

########## EnvNotSet #########
sub EnvNotSet
{
@_ == 1 or die;
my ($var) = @_;
die "ERROR: Environment variable '$var' not set!  Please set it
by editing set_env.sh and then (in bourne shell) issuing the
command '. set_env.sh'\n";
}

