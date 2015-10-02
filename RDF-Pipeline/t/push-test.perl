#! /usr/bin/perl -w

# Accept updated results for the given regression
# tests (or the most recently run regression test) and push
# them to github.  

use strict;

my $tmpRoot = "/tmp/rdfp";	# run-test.perl will put actual-files here
my $currentTest = "$tmpRoot/currentTest";  # Name of most recently run test

# my $wwwDir = $ENV{'RDF_PIPELINE_WWW_DIR'} or &EnvNotSet('RDF_PIPELINE_WWW_DIR');
my $devDir = $ENV{'RDF_PIPELINE_DEV_DIR'} or &EnvNotSet('RDF_PIPELINE_DEV_DIR');
my $moduleDir = "$devDir/RDF-Pipeline";
my $testsDir = "$moduleDir/t/tests";
chdir($testsDir) or die "ERROR: Could not chdir('$testsDir')\n";

my @testDirs = ();
while (my $arg = shift @ARGV) {
	if ($arg eq "-s") {
		die;
		}
	else	{
		push(@testDirs, $arg);
		}
	}

if (!@testDirs && -e $currentTest) {
	@testDirs = map { chomp; $_ } grep { m/\S/; } `cat '$currentTest'`;
	@testDirs or die "ERROR: no current test to accept and push.  Please specify a test name.\n";
	}

foreach my $dir (@testDirs) {
	# Accept the test
	warn "Accepting test $dir ...\n";
	my $acceptCmd = "accept-test.perl '$dir' ";
	warn "$acceptCmd\n";
	!system($acceptCmd) or die;

	# Add, in case it was not previously added
	my $addCmd = "git add '$dir' ";
	warn "$addCmd\n";
	!system($addCmd) or die;

	# Commit 
	my $commitCmd = "git commit -m 'Updated regression test results' '$dir' ";
	warn "$commitCmd\n";
	!system($commitCmd) or die;

	# push 
	my $pushCmd = "git push -u origin master";
	warn "$pushCmd\n";
	!system($pushCmd) or die;

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

