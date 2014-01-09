#! /usr/bin/perl -w

# Add a test case to the test suite by copying the current
# state of the Apache WWW root directory to a new test directory,
# and then run it via RDF-Pipeline/t/runtest.perl .

use strict;

@ARGV >= 1 && $ARGV[0] =~ m/^http(s?)\:/ or die "Usage: $0 URL [description]
where URL is the RDF Pipeline test URL to invoke for the new test.\n";
my $url = shift @ARGV;
my $description = join("_", @ARGV) || "";
$description =~ s/[^a-zA-Z\-\_0-9]//g;
$description =~ s/\A[^a-zA-Z0-9]*//;
$description =~ s/[^a-zA-Z0-9]*\Z//;

my $wwwDir = $ENV{'RDF_PIPELINE_WWW_DIR'} or &EnvNotSet('RDF_PIPELINE_WWW_DIR');
my $devDir = $ENV{'RDF_PIPELINE_DEV_DIR'} or &EnvNotSet('RDF_PIPELINE_DEV_DIR');
my $moduleDir = "$devDir/RDF-Pipeline";
my $testsDir = "$moduleDir/t/tests";
chdir($testsDir) or die "ERROR: Could not chdir('$testsDir')\n";

# Make the new test dir:
my $maxDir = 0;
map {m/\A\d+/; $maxDir = $& if $& > $maxDir; } grep { -d $_ } <0*>;
my $dir = sprintf("%04d", $maxDir+1);
($dir =~ m/^0/) or die "ERROR: Test number exceeded 999.  The numbered test directories
  must be renamed to add another digit, and this test script 
  ( $0 ) must be 
  updated to generate another digit.\n";
$dir .= "_$description" if $description;
mkdir($dir) or die;

# Generate an initial test-script, that can later be customized:
my $content = &ReadFile("<$moduleDir/t/helpers/test-script-template") or die;
$content =~ s/BEGIN_TEMPLATE_WARNING(.|\n)*END_TEMPLATE_WARNING\s*\n(\n?)//ms;
$content =~ s/\$URL\b/$url/g;
&WriteFile("$dir/test-script", $content);
my $chmodCmd = "chmod +x '$dir/test-script'";
# warn "chmodCmd: $chmodCmd\n";
!system($chmodCmd) or die;

# Create ReadMe.txt (initially empty) for documenting the test:
my $readme = "ReadMe.txt";
&WriteFile("$dir/$readme", "");

warn "Created test: $dir\n";

# Encourage the user to edit the test description in $readme:
my $editor = $ENV{EDITOR} || `which vi` || `which pico`;
chomp $editor;
if ($editor) {
	print STDERR "Edit test description $readme using $editor? [y] ";
	my $yes = <STDIN>;
	if ($yes =~ m/^y/i || $yes =~ m/^\s*$/) {
		my $cmd = "$editor '$dir/$readme'";
		system($cmd);
		}
	} else {
	warn "No editor found for editing test description $dir/$readme !\nPlease set \$EDITOR !\n";
	}
warn "\n";

# Create setup-files and run the test (which will initially fail):
my $runCmd = "$moduleDir/t/update-test-setup.perl '$dir'";
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


