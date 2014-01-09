#! /usr/bin/perl -w

# This file is used by accept-test.perl to detect when filter-actual.perl
# or filter-expected.perl has been modified.  If either of those
# files is different from this file (ignoring whitespace and comments),
# then it is deemed to have changed.
# It can also be used to restore those files back to their original
# state after they have been modified.

# When this file is used as a filter-actual.perl or filter-expected.perl
# it will be run on each actual or expected file (respectively), and
# can modify that file as needed or even delete it.

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

        print $tmpfh $_;
        }
close($tmpfh) || die;
rename($tmp, $f) || die;

