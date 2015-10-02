#! /usr/bin/perl -w

# Run one or more regression tests and commit and push the ones that pass.

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

	# Run the test
	my $runCmd = "run-test.perl -q '$dir' ";
	warn "$runCmd\n";
	my $passed = !system($runCmd);
	if ($passed) { warn "Passed: $dir\n"; }
	else {
		warn "FAILED: $dir\n";
		next;
		}

	# Accept, commit and push the test
	my $acceptCmd = "push-test.perl '$dir' ";
	# warn "$acceptCmd\n";
	!system($acceptCmd) or exit 1;

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

