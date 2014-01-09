#! /usr/bin/perl -w

# This will be used to filter each of the actual result files from
# running a regression test.
# It will be run with the filename as its only argument, and should
# modify the file in place.
# 
# This script should be temporarily modified as needed when changes
# are made that affect the format of the result files.

use strict;

# Skip the given file?
my $f = $ARGV[0];
exit(0) if $f =~ m|FILE_THAT_SHOULD_NOT_BE_FILTERED|;
# exit(0) if $f !~ m|FILE_THAT_SHOULD_BE_FILTERED|;

# The given file will be filtered by first writing to a tmp file:
my $tmp = "/tmp/filtered-$$.txt";
open(my $tmpfh, ">$tmp") || die;
while (<>) {
        # Make whatever changes are needed:
        # s/ETag\: \"(\d)/ETag\: \"LM$1/;

        # s|\/Private||g;

        print $tmpfh $_;
        }
close($tmpfh) || die;
rename($tmp, $f) || die;

