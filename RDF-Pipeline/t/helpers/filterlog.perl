#! /usr/bin/perl -w

# Remove dates and other unneeded chaff from the apache log, 
# to enable easier comparison of log output.
#
# This line:
# 127.0.0.1 - - [19/Jan/2012:14:46:48 -0500] "GET /node/addone HTTP/1.1" 304 243 "-" "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.2.24) Gecko/20111107 Ubuntu/10.04 (lucid) Firefox/3.6.24"
#
# becomes:
# "GET /node/addone HTTP/1.1" 304

use strict;

while (<>) {
	print "$1\n" if m/^[^\"]*(\"[^\"]*\" +\d+)/;
	}

