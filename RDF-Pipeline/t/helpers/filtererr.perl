#! /usr/bin/perl -w

# Remove dates and other unneeded chaff from the apache error log, 
# to enable easier comparison of log output.
#
# This line:
# [Sun Mar 04 21:34:09 2012] [error] [client 127.0.0.1] INTERNAL ERROR: FILE rdf
s:subClassOf Node
#
# becomes:
# [Mon Feb 14 12:43:23 2011] [error] [client 127.0.0.1] INTERNAL ERROR: FILE rdf
s:subClassOf Node

use strict;

while (<>) {
	print "$1\n" if m/^[^\"]*(\"[^\"]*\" +\d+)/;
	}

