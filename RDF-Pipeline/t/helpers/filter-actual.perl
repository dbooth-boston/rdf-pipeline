#! /usr/bin/perl -w

# When this file is used as a filter-actual.perl or filter-expected.perl
# it will be run on each actual or expected plain file
# (respectively), and can modify that file as needed -- perhaps even
# renaming it or deleting it.  It is not run on directories
# because renaming or deleting them would interfere with subsequent
# files on the list of those to be filtered.  Instead, run-test has
# an option -d to delete empty directories.

use strict;
use File::Path qw(make_path remove_tree);

my $f = $ARGV[0];
die if -d $f;

# Skip the given file based on its name?
exit 0 if $f =~ m|FILE_THAT_SHOULD_NOT_BE_FILTERED|;
# exit 0 if $f !~ m|FILE_THAT_SHOULD_BE_FILTERED|;

# Change the name of the given file?
my $newName = $f;
$newName =~ s/cache\/(URI|FILE|GraphNode|ExampleHtmlNode)/cache/g;
$newName =~ s/_HASH([a-zA-Z0-9_\-]+)//g;
$newName =~ s/SHORT_//g;

# $newName =~ s#lm\/(URI|FILE|GraphNode|ExampleHtmlNode)\/(.*)$#cache/$1/$2/lm.txt#;
if ($newName ne $f) {
	&MakeParentDirs($newName);
	rename($f, $newName) || die "$0: Could not rename $f to $newName\n";
	# Clean up orphaned directories?  This may or may not be needed:
	&DeleteEmptyDirs($f);
	$f = $newName;
	}

# Delete the given file?
# if ($f =~ m/FILE_THAT_SHOULD_BE_DELETED/) {
if ($f =~ m/hashMap\.txt$/) {
	unlink $f || die if -f $f;
	&DeleteEmptyDirs($f);
	exit 0;
	}

# The given file will be filtered by first writing to a tmp file:
my $tmp = "/tmp/filtered-$$.txt";
open(my $tmpfh, ">$tmp") || die;
open(my $fh, "<$f") || die;
while (<$fh>) {
        # Make whatever changes are needed:
        # s/ETag\: \"(\d)/ETag\: \"LM$1/;

	s/cache\/(URI|FILE|GraphNode|ExampleHtmlNode)/cache/g;
	# s#lm\/(URI|FILE|GraphNode|ExampleHtmlNode)\/(.*)$#cache/$1/$2/lm.txt#;
	s/_HASH([a-zA-Z0-9_\-]+)//g;
	s/SHORT_//g;

        print $tmpfh $_;
        }
close($fh) || die;
close($tmpfh) || die;
rename($tmp, $f) || die;
exit 0;

#################################################################
#                Helper Functions
#################################################################

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
        next if $fDir eq "";    # Hit the root?
        make_path($fDir);
        -d $fDir || die "ERROR: Failed to create directory: $fDir\n ";
        }
}

########## DeleteEmptyDirs ############
# Delete any empty directories, following the path up the tree.
sub DeleteEmptyDirs
{
foreach my $f (@_) {
	my $dir = $f;
	while (1) {
		# rmdir will succeed only if the dir is empty, so this is safe:
		rmdir $dir if -d $dir;
		last if $dir !~ s|\/[^\/]*$||;
		last if $dir eq "";
		}
        }
}

