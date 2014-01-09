#!/usr/bin/perl -w

# Test of using RDF::Trine, in preparation for converting to it.

use strict;

use RDF::Helper;
use RDF::Trine;
use RDF::Trine::Serializer;

my $namespacesHashRef = {
          p => 'http://purl.org/pipeline/ont#',
          rdf => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
	  log => "http://www.w3.org/2000/10/swap/log#" ,
	  rdfs => "http://www.w3.org/2000/01/rdf-schema#" ,
          # '#default' => "http://purl.org/rss/1.0/",
	};

my $model = RDF::Trine::Model->temporary_model;
my $parser = RDF::Trine::Parser->new( 'turtle' );
my $base_uri = "http://example/";
$parser->parse_file_into_model( $base_uri, '/tmp/pipeline.ttl', $model );

my @s = RDF::Trine::Serializer::serializer_names();
print "Serializers: @s\n";
my $serializer = RDF::Trine::Serializer->new('turtle', 
	namespaces => $namespacesHashRef );
open(my $fh, ">/tmp/junk.nt") or die;
$serializer->serialize_model_to_file( $fh, $model );
close($fh);

exit 0;

