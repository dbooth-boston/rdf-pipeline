#! /usr/bin/perl -w

# This can be used to filter each of the expected-files.
# It will be run with the filename as its only argument.
#
# This script should be temporarily modified as needed when changes
# are made that affect the format of the actual result files.

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

	my $old = quotemeta('Apache/2.2.14 (Ubuntu)');
	my $new = 'Apache/2.2.22 (Ubuntu)';
	s/$old/$new/g;

	$old = quotemeta('http://localhost:28080/openrdf-workbench/repositories/owlimlite');
	$new = 'http://localhost:8080/openrdf-workbench/repositories/rdf-pipeline-test';
	s/$old/$new/g;

	$old = quotemeta('rdf-pipeline-test/"');
	$new = 'rdf-pipeline-test"';
	s/$old/$new/g;

	print $tmpfh $_;
	}
close($tmpfh) || die;
rename($tmp, $f) || die;

