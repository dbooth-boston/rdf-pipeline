#! /usr/bin/env perl

# Abbreviate repetitive items in an rdf-summary.  Reads stdin, writes stdout.
#
# Copyright 2014 by David Booth
# This software is available as free and open source under
# the Apache 2.0 software license, which may be viewed at
# http://www.apache.org/licenses/LICENSE-2.0.html
# Code home: https://github.com/dbooth-boston/rdf-pipeline/
#
# EXAMPLE INPUT:
#   valtable_333:11 valtable_337:1 valtable_42:22
#
# EXAMPLE OUTPUT:
#   valtable_333:11 ... valtable_42:22

while (<>) {
	s/( (\w+\:[_a-zA-Z]+)[0-9]+\:[0-9]+)( (\2)[0-9]+\:[0-9]+)+( (\2)[0-9]+\:[0-9]+)/$1 ...$5/g;
	print;
	}

