#! /usr/bin/perl -w

# Change dates, LMs, ETags, server names, paths and HASH codes to constants, 
# so that when files are compared during regression testing, 
# they do not show up as spurious differences.

use strict;

my $dayP = "Sun|Mon|Tue|Wed|Thu|Fri|Sat";
my $monP = "Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec";

while (<>) {
	############# Dates1 ###############
	# [Sun Mar 04 21:34:09 2012] 
	#  Fri Aug  2 09:56:15 EDT 2013
	# s/($dayP)( +)($monP)( +)(\d{1,2})( +)\d\d\:\d\d\:\d\d( +)(E[DS]T +)?\d\d\d\d/Sat Mar 03 03:03:03 2012\]/g;
	# s/($dayP) ($monP)( +)(\d{1,2}) \d\d\:\d\d\:\d\d(( E[DS]T)?) \d\d\d\d/Sat Mar 03 03:03:03$5 2012/g;
	# Allow any timezone name of 1-3 letters, which is not quite
	# what RFC 822 sec 5.1 says, but should be good enough:
	# http://www.ietf.org/rfc/rfc0822.txt
	# 1       2      3   4                         56
	s/($dayP) ($monP)( +)(\d{1,2}) \d\d\:\d\d\:\d\d(( ([A-Z]{1,3}))) \d\d\d\d\b/Sat Mar 03 03:03:03 EDT 2012/g;
	# No timezone name:
	# 1       2      3   4                         
	s/($dayP) ($monP)( +)(\d{1,2}) \d\d\:\d\d\:\d\d \d\d\d\d\b/Sat Mar 03 03:03:03 2012/g;

	############# Dates2 ###############
	# Date: Thu, 19 Jan 2012 18:26:00 GMT
	# s/^Date:.*/Date: Thu, 19 Jan 2012 18:26:00 GMT/;
	s/($dayP)\, \d{1,2} ($monP) \d\d\d\d \d{1,2}\:\d\d\:\d\d GMT/Sat, 03 Mar 2012 03:03:03 GMT/g;

	############# ETags ###############
	# ETag: "LM1326850256.504565000001"
	# s/^ETag:.*/ETag: "LM1326850256.504565000001"/;
	# 8/2/13 dbooth changed this to substitute not only ETag headers
	# but anywhere these LMs occur.  They are 10 digits + "." + 12 digits.
	# s/([^\d]|^)(\d{10})\.(\d{12})([^\d]|$)/$1 . "1326850256.504565000001" . $4/e;
	s/([^\d]|^)(\d{10})\.(\d{12})([^\d]|$)/$1 . "1326111111.111111000001" . $4/ge;

	############# HASH codes ###############
	# HASH(0x7f8c80a38e40)
	s/\bHASH\(0x([a-f0-9]{12})\)/HASH\(0x111111111111\)/g;

	############# Server names ###############
	# Server: Apache/2.2.22 (Ubuntu)
	s|Server: Apache/[\d\.]+ +\([^\)]*\)|Server: Apache/2.2.22 (Ubuntu)|g;

	############# Server paths ###############
	# /home/dbooth/rdf-pipeline/Private/www/node/
	s|/home/dbooth/rdf-pipeline/Private/www/|/var/www/|g;

	print;
	}

