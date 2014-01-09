#! /usr/bin/perl -w

# Update the setup-files of a test case by re-copying the current
# state of the Apache WWW root directory to the test directory,
# and then run the test via RDF-Pipeline/t/run-test.perl .
#
# This is typically used to reset the setup-files to the proper
# server state that should exist *before* running the test.  For
# example, test 0013 expects a starting state that is the result
# of running test 0012.  If test 0013 fails with this diff:
#
#   diff -r -b -w -x lm -x ont -x '.*' /tmp/rdfp/0013_No_changes_should_304/expected
#   -filtered/test/apacheAccess.log /tmp/rdfp/0013_No_changes_should_304/actual-filt
#   ered/test/apacheAccess.log
#   2c2
#   < "GET /node/multiplier.txt HTTP/1.1" 304
#   ---
#   > "GET /node/multiplier.txt HTTP/1.1" 200
#
# it can probably be fixed by running:
#
#   $ run-test.perl 0012_Modified_multipliertxt/
#   $ update-test-setup.perl 0013_No_changes_should_304/

use strict;

my $wwwDir = $ENV{'RDF_PIPELINE_WWW_DIR'} or &EnvNotSet('RDF_PIPELINE_WWW_DIR');
my $devDir = $ENV{'RDF_PIPELINE_DEV_DIR'} or &EnvNotSet('RDF_PIPELINE_DEV_DIR');
my $moduleDir = "$devDir/RDF-Pipeline";
my $testsDir = "$moduleDir/t/tests";
chdir($testsDir) or die "ERROR: Could not chdir('$testsDir')\n";

my @testDirs = @ARGV;
# Do not default to the $currentTest, because normally it is the *next*
# test that you want to update:
die "ERROR: Test name required.\n" if !@testDirs;

@testDirs == 1 or die "Usage: $0 [nnnn]
where nnnn is the numbered test directory to be updated.\n";
my $dir = $testDirs[0];
-e $dir or die "ERROR: Test directory not found: $testsDir/$dir\n";

# Capture the initial WWW state as the setup-files:
my $setupFiles = "$dir/setup-files";
my $setupCmd = "$moduleDir/t/helpers/copy-dir.perl -s '$wwwDir' '$setupFiles'";
# warn "setupCmd: $setupCmd\n";
!system($setupCmd) or die;
# Empty out the "test" subdir, because that's for test results:
$setupCmd = "$moduleDir/t/helpers/copy-dir.perl -s '/dev/null' '$setupFiles/test'";
!system($setupCmd) or die;

warn "Running test $dir , which should fail if
expected-files have not yet been created/updated ...\n";
my $runCmd = "$moduleDir/t/run-test.perl '$dir'";
# warn "runCmd: $runCmd\n";
system($runCmd);

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

############ WriteFile ##########
# Write a file.  Examples:
#   &WriteFile("/tmp/foo", $all)   # Same as &WriteFile(">/tmp/foo", all);
#   &WriteFile(">$f", $all)
#   &WriteFile(">>$f", $all)
sub WriteFile
{
@_ == 2 || die;
my ($f, $all) = @_;
my $ff = (($f =~ m/\A\>/) ? $f : ">$f");    # Default to ">$f"
my $nameOnly = $ff;
$nameOnly =~ s/\A\>(\>?)//;
open(my $fh, $ff) || die;
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


