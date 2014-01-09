#! /usr/bin/perl -w

# This test script is normally run from "make test", and runs
# all tests in the numbered subdirectories.
# 
# Normally "make test" would be run by "make install" *before* 
# a module is installed by "make install".  However, since this 
# module is only testable through Apache, it needs to be installed 
# before it can be tested.  (Is there another way this should be handled?)

#########################
# Set up for using Test::More.

my $wwwDir;
my $moduleDir;
my $nTests;
my @testDirs;
BEGIN {
  $wwwDir = $ENV{'RDF_PIPELINE_WWW_DIR'} or &EnvNotSet('RDF_PIPELINE_WWW_DIR');
  my $devDir = $ENV{'RDF_PIPELINE_DEV_DIR'} or &EnvNotSet('RDF_PIPELINE_DEV_DIR');
  $moduleDir = "$devDir/RDF-Pipeline";

  my $testsDir = "$moduleDir/t/tests";
  chdir($testsDir) or die "ERROR: Could not chdir('$testsDir')\n";
  -e $wwwDir or die "ERROR: No WWW root: $wwwDir\n";
  -d $wwwDir or die "ERROR: WWW root is not a directory: $wwwDir\n";
  @testDirs = sort grep { -d $_ } <0*>;
  $nTests = scalar(@testDirs);
  $nTests or die "ERROR: No numbered test directories found in $testsDir\n";

  ########## EnvNotSet #########
  sub EnvNotSet
    {
    @_ == 1 or die;
    my ($var) = @_;
    die "ERROR: Environment variable '$var' not set!  Please set it
    by editing set_env.sh and then (in bourne shell) issuing the 
    command '. set_env.sh'\n";
    }

  }

use Test::More tests => $nTests;
### The RDF::Pipeline module will be loaded into Apache -- not loaded here.
# BEGIN { use_ok('RDF::Pipeline') };

#########################
# This section is where our tests are run.

foreach my $testDir (@testDirs) {
    my $runCmd = "$moduleDir/t/run-test.perl -q '$testDir'";
    # warn "runCmd: $runCmd\n";
    is(system($runCmd), 0, $runCmd);
    }

exit 0;

