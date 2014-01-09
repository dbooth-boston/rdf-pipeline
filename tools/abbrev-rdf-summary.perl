#! /usr/bin/env perl

# Abbreviate repetitive items in an rdf-summary.  Reads stdin, writes stdout.
#
# Copyright 2013 by David Booth
# Code home: http://code.google.com/p/rdf-pipeline/
# See license information at http://code.google.com/p/rdf-pipeline/ 
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

