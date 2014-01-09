#!/usr/bin/perl -w

# Test of using RDF::Trine, in preparation for converting to it.

my $sourceTurtleFile = shift @ARGV;
$sourceTurtleFile ||= "/home/dbooth/rdf-pipeline/trunk/www/node/pipeline.ttl";

use strict;
use warnings;
use RDF::Trine;
use RDF::Query;

my $hr = {};
my @keys = keys %{$hr};
my $n = scalar(@keys);
warn "n before: $n\n";
# my $foo = $hr->{bar}->{baz}->{buz};
my $foo = (($hr->{bar} || {})->{baz} || {})->{buz};
@keys = keys %{$hr};
$n = scalar(@keys);
warn "Succeeded! n after: $n\n";
warn "keys: @keys\n";
exit 0;

my $model = RDF::Trine::Model->temporary_model;
my $parser = RDF::Trine::Parser->new( 'turtle' );

my $baseUri = 'http://example/';
$parser->parse_file_into_model( $baseUri, $sourceTurtleFile, $model );

my $hashRef = $model->as_hashref;

foreach my $sk (sort keys %{$hashRef} ) {
  warn "Subject: $sk\n";
  my $pRef = $hashRef->{$sk};
  foreach my $pk (sort keys %{$pRef}) {
    warn "  Predicate: $pk\n";
    my $oRef = $pRef->{$pk};
    foreach my $ok (@{$oRef}) {
      my $type = $ok->{type} or die;
      if ($type eq 'literal') {
        my $lang = $ok->{lang} || "";
        my $atLang = $lang ? '@' . $lang : "";
        my $datatype = $ok->{datatype} || "";
        my $upDatatype = $datatype ? '^^<' .$datatype. '>' : "";
        my $value = $ok->{value};	# TODO: Escape!
        warn "    Literal: \"$value\"$atLang$upDatatype\n";
        }
      elsif ($type eq 'uri') {
        my $value = $ok->{value};	# TODO: Escape!
        warn "    URI: \<$value\>\n";
        }
      elsif ($type eq 'bnode') {
        my $value = $ok->{value};	
        warn "    bnode: $value\n";
        }
      else { die; }
      }
    }
}

exit 0;

