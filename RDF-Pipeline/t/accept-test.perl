#! /usr/bin/perl -w

# Accept the current actual-files as correct, by copying them
# to expected-files (after deleting the current expected files).
#
# Options:
# 	-s 	Try to add the test into subversion.
#	-r	Run the test before accepting the results.

use strict;

my $tmpRoot = "/tmp/rdfp";	# run-test.perl will put actual-files here
my $currentTest = "$tmpRoot/currentTest";  # Name of most recently run test

# my $wwwDir = $ENV{'RDF_PIPELINE_WWW_DIR'} or &EnvNotSet('RDF_PIPELINE_WWW_DIR');
my $devDir = $ENV{'RDF_PIPELINE_DEV_DIR'} or &EnvNotSet('RDF_PIPELINE_DEV_DIR');
my $moduleDir = "$devDir/RDF-Pipeline";
my $testsDir = "$moduleDir/t/tests";
chdir($testsDir) or die "ERROR: Could not chdir('$testsDir')\n";

my $svnOption = 0;	# -s option
my $runOption = 0;	# -r option
my @testDirs = ();
while (my $arg = shift @ARGV) {
	if ($arg eq "-s") {
		$svnOption = 1;
		}
	elsif (0 && $arg eq "-r") {
		# $runOption = 1;
		warn "WARNING: -r option is currently ignored.\n";
		}
	else	{
		push(@testDirs, $arg);
		}
	}

if (!@testDirs && -e $currentTest) {
	@testDirs = map { chomp; $_ } grep { m/\S/; } `cat '$currentTest'`;
	@testDirs or die "ERROR: no current test to accept.  Please specify a test name.\n";
	warn "Accepting test $testDirs[0] ...\n";
	}

foreach my $dir (@testDirs) {
	!system("echo '$dir' > '$currentTest'") or die;
	my $tmpTDir = "$tmpRoot/$dir/actual-files";
	-e $tmpTDir || die "ERROR: No actual-files to accept: $tmpTDir\n";

	# Copy the $tmpTDir files to expected-files
	my $copyCmd = "$moduleDir/t/helpers/copy-dir.perl -s '$tmpTDir' '$dir/expected-files'";
	# warn "copyCmd: $copyCmd\n";
	!system($copyCmd) or die;
	# Add the test to svn?
	if (!$svnOption) {
		warn "Remember to add $dir to subversion, or use: accept-test.perl -s '$dir'\n"
			if !-e "$dir/.svn";
		next;
		}
	if (-e "$dir/.svn") {
		warn "Already in subversion: $dir\n";
		next;
		}
	warn "Attempting to add $dir to subversion ...\n";
	my $svnCmd = "cd '$devDir' ; svn -q add 'RDF-Pipeline/t/tests/$dir'";
	warn "$svnCmd\n";
	!system($svnCmd) or die;
	}

# Warn if filters may need to be reset:
my @filters = (		"$moduleDir/t/helpers/filter-expected.perl",
			"$moduleDir/t/helpers/filter-actual.perl" );
foreach my $filter (@filters) {
	my $f = $filter;
	$f =~ s|^.*\/||;
	warn "WARNING: Filter changed: $f Do you need to reset it?\n"
		if &FilterChanged($filter);
	}

exit 0;

########## FilterChanged #########
sub FilterChanged
{
@_ == 1 || die;
my ($newFilter) = @_;
open(my $newFh, "<$newFilter") || die;
my $newFilterString = join("", map {s/\#.*//; s/[\s\n\r]+//ms; $_} <$newFh>);
close($newFh) || die;
my $oldFilter = "$moduleDir/t/helpers/filter-original.perl";
open(my $oldFh, "<$oldFilter") || die;
my $oldFilterString = join("", map {s/\#.*//; s/[\s\n\r]+//ms; $_} <$oldFh>);
close($oldFh) || die;
return( $oldFilterString ne $newFilterString );
}


########## EnvNotSet #########
sub EnvNotSet
{
@_ == 1 or die;
my ($var) = @_;
die "ERROR: Environment variable '$var' not set!  Please set it
by editing set_env.sh and then (in bourne shell) issuing the 
command '. set_env.sh'\n";
}

