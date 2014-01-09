#!/usr/bin/perl -w

# Test of using RDF::Trine, in preparation for converting to it.

use strict;

use RDF::Helper;
use RDF::Trine;
use RDF::Trine::Serializer;

if (0) {
  my $rdf = RDF::Helper->new(
      BaseInterface => 'RDF::Trine',
      namespaces => {
          p => 'http://purl.org/pipeline/ont#',
          rdf => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
	  log => "http://www.w3.org/2000/10/swap/log#" ,
	  rdfs => "http://www.w3.org/2000/01/rdf-schema#" ,
          # '#default' => "http://purl.org/rss/1.0/",
     }
  );
}

my $parser = RDF::Trine::Parser->new( 'turtle' );
my $base_uri = "http://localhost/node/pipeline.ttl#";
for (my $i=0; $i<($ARGV[0] || 1); $i++) {
	# my $model = RDF::Trine::Model->temporary_model;
	$parser->parse_file_into_model( $base_uri, '/tmp/pipeline.ttl', $rdf );
	$rdf->serialize(filename => '/tmp/junk.nt', format => 'ntriple')
	}

exit 0;

