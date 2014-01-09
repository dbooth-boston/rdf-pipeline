#! /usr/bin/env ste.perl

# Copyright 2012 by David Booth <david@dbooth.org>
# See license info at: http://code.google.com/p/rdf-pipeline/

# This is a sample updater written as a SPARQL template.
# The template should be expanded as:
#
#  export QUERY_STRING='min=2&max=99&property=givenName'
#  ste.perl sample-updater.rut -t http://example/this -i http://example/in -i William -i Taffy -o http://example/out > sample-updater-expanded.ru

##############################################################
########## Template variables are declared below #############
##############################################################


##############################################################
########## Results of expansion can be seen below ############
##############################################################

PREFIX foaf:  <http://xmlns.com/foaf/0.1/>

# Env: THIS_URI: http://example/this
# in3: Taffy max: 99
# QUERY_STRING: min=2&max=99&property=givenName
# These should be unchanged: $inUriExtra  Billion  EmBill 

DROP SILENT GRAPH <http://example/in> ;
DROP SILENT GRAPH <http://example/out> ;

CREATE SILENT GRAPH <http://example/in> ;
CREATE SILENT GRAPH <http://example/out> ;

INSERT DATA {
  GRAPH <http://example/in> {
	<http://example/president25> foaf:givenName "William" .
	<http://example/president25> foaf:familyName "McKinley" .
	<http://example/president27> foaf:givenName "William" .
	<http://example/president27> foaf:familyName "Taft" .
	<http://example/president42> foaf:givenName "William" .
	<http://example/president42> foaf:familyName "Clinton" .
    }
  }
;

INSERT { 
  GRAPH <http://example/out> {
    ?s foaf:givenName ?v .
    }
  }
WHERE { 
  GRAPH <http://example/in> {
    ?s foaf:givenName ?v .
    }
  } 
;

