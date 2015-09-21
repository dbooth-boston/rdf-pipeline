#! /usr/bin/perl -w

# Given a pipeline definition, as a set of nodes and arcs,
# render it in HTML.

use strict;

# Temporarily output a fixed pipeline diagram.

my $all = `cat /home/dbooth/rdf-pipeline/trunk/tools/pedit/nodes.html`;
print $all;
exit 0;

###################################################
die "ERROR: Dynamic image creation is not implemented yet.\n";

use Graph 0.50;
use Graph::Easy;

use Data::Dumper;

my $graph = Graph::Easy->new();
$graph->add_edge ('b', 'c');
$graph->add_edge ('a', 'b');
$graph->add_edge ('a', 'd');
$graph->add_edge ('c', 'd');
$graph->add_edge ('c', 'a');

# $graph->output_format('txt');
# $graph->output();
# print $graph->as_ascii();
# print $graph->as_svg();

$graph->layout();
my $cells = $graph->{cells};
my $nodes = $graph->{nodes};
my ($rows,$cols);

for my $k (sort keys %$nodes)
	{
	my $node = $nodes->{$k};
	# my $x = $note->{x};
	# my $y = $note->{y};
	my $x = $node->{x};
	my $y = $node->{y};
	print "x: $x y: $y\n";
	# print Dumper($node);
	exit 0;
	}
# find all x and y occurances to sort them by row/columns
for my $k (sort keys %$cells)
	{
	my ($x,$y) = split/,/, $k;
	my $node = $cells->{$k};
	print "$x $y\n";
	print Dumper($node);
	}
