#! /usr/bin/perl -w

# Recursively compare the contents of the given two directories (excluding 
# "lm", "ont" and hidden subdirectories/files), exiting with 0 iff 
# they are the same.  
#
# Option:
#	-q	Quiet: only set return status, instead of showing diffs.

use strict;

my $debug = 0;
my $quiet = "";
$quiet = shift @ARGV if @ARGV && $ARGV[0] eq "-q";
my $expectedFiles = shift @ARGV || die;
my $resultFiles = shift @ARGV || die;

# -d $expectedFiles or exit 1;
# -d $resultFiles or exit 1;

use File::DirCompare;
use File::Basename;

my $result = 0; 
if (-d $expectedFiles && -d $resultFiles) {
	# Two directories.  Global $result will be set as a side effect
	# if there is any difference.
	File::DirCompare->compare($expectedFiles, $resultFiles, \&Difference, {
		cmp             => \&CompareFiles,
		exclude         => \&Exclude,
		});
	}
else	{
	# Plain or mixed files
	$result = &CompareFiles($expectedFiles, $resultFiles);
	}
exit $result;

################ Exclude ################
# Must return true if the given file should be excluded from comparison.
sub Exclude
{
  my ($f) = @_;
  # my $cmd = "diff -b -w $quiet -x lm -x ont -x '.*' '$expectedFiles' '$resultFiles'";
  return 1 if $f eq "lm";
  return 1 if $f eq "ont";
  return 1 if $f =~ m/^\./;
  return 0;
}

################ Difference ################
# Called on file pairs that differ.
sub Difference
{
  my ($a, $b) = @_;
  if (! $b) {
    printf "Only in %s: %s\n", dirname($a), basename($a) if !$quiet;
  } elsif (! $a) {
    printf "Only in %s: %s\n", dirname($b), basename($b) if !$quiet;
  } else {
    # print "Files $a and $b differ\n" if !$quiet;
  }
$result = 1;
}


################ CompareFiles #################
# The two files are know to exist, but one may be a directory.
sub CompareFiles
{
@_ == 2 || die;
my ($expectedFiles, $resultFiles) = @_;
# my $cmd = "diff -b -w $quiet -x lm -x ont -x '.*' '$expectedFiles' '$resultFiles'";
my $cmd = "diff -b -w $quiet '$expectedFiles' '$resultFiles'";
# warn "cmd: $cmd\n";
###### TODO: Change this to use the saved Content-type associated with
###### the files, as described in issue-53:
###### http://code.google.com/p/rdf-pipeline/issues/detail?id=53
###### Or maybe implement smarter RDF sniffing?
# Don't try to compare as Turtle if the files are identical anyway:
if (-f $expectedFiles && -f $expectedFiles) {
	`cmp '$expectedFiles' '$resultFiles'`;
	return 0 if !$?;
	}
my $isTurtle = (&IsTurtle($expectedFiles) && &IsTurtle($resultFiles));
if ($isTurtle) {
	$cmd = "rdfdiff";
	$cmd .= " -b" if $quiet;
	$cmd .= " -f turtle -t turtle '$expectedFiles' '$resultFiles'";
	}
print "$cmd\n" if $debug;
my $output = `$cmd`;
if ($?) {
	print "$cmd\n";
	print $output;
	return 1;
	}
return 0;
}


################## IsTurtle #####################
# Sniff to see if the given file looks like Turtle RDF.
sub IsTurtle
{
my $f = shift or die;
return 0 if !-f $f;
open(my $fh, "<$f") or die "$0: ERROR: File not found: $f\n";
my @lines = ();
my $maxLines = 100;
for (my $i=0; $i<$maxLines; $i++) {
	my $line = <$fh>;
	last if !defined($line);
	push(@lines, $line);
	}
close($fh);
# Check for SPARQL keyword.
my @sparqlKeyword = qw(select construct describe ask
	load clear drop create add move copy insert delete);
my $sparqlPattern = join("|", @sparqlKeyword);
my $isSparql = grep {m/^\s*($sparqlPattern)\s/i} @lines;
return 0 if $isSparql;
# If it isn't SPARQL, and PREFIX or BASE appears first (after comments),
# then assume it is Turtle.
my $isTurtle = 0;
foreach my $line ( @lines ) {
	next if $line =~ m/^\s*(\#.*)?$/;
	if ($line =~ m/^\s*(\@?)(prefix|base)\s/i) {
		$isTurtle = 1;
		last;
		}
	else	{
		last;
		}
	}
return $isTurtle;
}

