#!/usr/bin/perl -w

# Summary of schema implied by RDF instance data -- classes and predicates.
# Files are read from command line or stdin, in Turtle format.
#
# Copyright 2013 by David Booth
# Code home: http://code.google.com/p/rdf-pipeline/
# See license information at http://code.google.com/p/rdf-pipeline/ 

use strict;

use RDF::Helper::Constants qw( :all );
use RDF::Trine;
use RDF::Trine::Model;
use RDF::Trine::Statement;
use RDF::Trine::Node::Resource;

my %namespaces;		# Remembers namespaces seen, stripped by &ShortenUri

my $RDF_TYPE = RDF::Trine::Node::Resource->new(RDF_TYPE);
my $RDF_NIL = RDF::Trine::Node::Resource->new(RDF_NIL);
my $RDF_LIST = RDF::Trine::Node::Resource->new(RDF_LIST);
my $RDF_FIRST = RDF::Trine::Node::Resource->new(RDF_FIRST);
my $RDF_REST = RDF::Trine::Node::Resource->new(RDF_REST);
my $RDFS_CLASS = RDF::Trine::Node::Resource->new(RDFS_CLASS);
my $RDFS_SUBCLASS_OF = RDF::Trine::Node::Resource->new(RDFS_SUBCLASS_OF);

# my $subject = RDF::Trine::Node::Resource->new('http://example.org/aircraft/B787');
# my $predicate = RDF::Trine::Node::Resource->new('http://purl.org/dc/terms/title');
# my $object = RDF::Trine::Node::Literal->new('Boeing 787', 'en');
# my $ss = $subject->as_string();
# print "subject: $ss\n";
# my $statement = RDF::Trine::Statement->new($subject, $predicate, $object);
my $model = RDF::Trine::Model->temporary_model;
my $parser = RDF::Trine::Parser->new( 'turtle' );
my $base_uri = "http://example/";
print "===== Input Summary =====\n";
foreach my $file (@ARGV) {
	print "Parsing turtle: $file \n";
	$parser->parse_file_into_model( $base_uri, $file, $model );
	}
if (!@ARGV) {
	my $turtle = join("", <>);	# Slurp stdin
	$parser->parse_into_model( $base_uri, $turtle, $model );
	}
my $n = $model->size();
print "Total triples: $n\n";

my %typesOf;		# Node -> hash of declared types or datatypes
my %typeInstances;	# {URI, LITERAL, BLANK} -> hash of instances
my %datatypeValues;	# datatypes -> hash of values
my %predicateSubjects;	# predicates -> hash of subjects
my %predicateObjects;	# predicates -> hash of objects
my %isDatatype;		# Remember whether a URI is a datatype
my %subjectPredicates;	# Maps subjects -> hash of predicates
my $si = $model->get_statements(undef, undef, undef);
while (my $ts = $si->next()) {
	my $s = $ts->subject();
	my $p = $ts->predicate();
	my $o = $ts->object();
	$subjectPredicates{$s}->{$p} = 1;
	# print "\t$s $p $o\n";
	if ($p->equal($RDF_TYPE)) {
		$typesOf{$s}->{$o} = 1;
		$typesOf{$o}->{$RDFS_CLASS} = 1;
		}
	if ($p->equal($RDFS_SUBCLASS_OF)) {
		$typesOf{$s}->{$RDFS_CLASS} = 1;
		$typesOf{$o}->{$RDFS_CLASS} = 1;
		}
	my $t = $o->type();
	$typeInstances{$t}->{$o} = 1;
	if ($t eq "LITERAL") {
		my $dt = $o->literal_datatype() || "(untyped)";
		$typesOf{$o}->{$dt} = 1;
		#### TODO: This naively assumes that a datatype URI will
		#### never be used as a class name in an rdf:type declaration:
		$isDatatype{$dt} = 1;
		my $v = $o->value();
		$datatypeValues{$dt}->{$v} = 1;
		# print "  LITERAL($dt): $s $p $o\n";
		}
	$typesOf{$s}->{$RDF_LIST} = 1 if $s->equal($RDF_NIL);
	$typesOf{$o}->{$RDF_LIST} = 1 if $o->equal($RDF_NIL);
	$typesOf{$s}->{$RDF_LIST} = 1 if $p->equal($RDF_FIRST);
	if ($p->equal($RDF_REST)) {
		$typesOf{$s}->{$RDF_LIST} = 1;
		$typesOf{$o}->{$RDF_LIST} = 1;
		}
	$predicateSubjects{$p}->{$s} = 1;
	$predicateObjects{$p}->{$o} = 1;
	# print "\t$s $p $o type: $t\n";
	}

print "Nodes by kind:  ";
foreach my $t (sort keys %typeInstances) {
	my @instances = keys %{$typeInstances{$t}};
	my $ni = scalar(@instances);
	print "$t:$ni  ";
	}
print "\n";

print "Literals by datatype:  ";
foreach my $dt (sort keys %datatypeValues) {
	my @values = keys %{$datatypeValues{$dt}};
	my $nv = scalar(@values);
	my $sdt = &ShortenUri($dt);
	print "$sdt:$nv  ";
	}
print "\n";
print "\n";

# Determine the classes for each subject (including any that are UNK):
my %classInstances;	# Maps subject classes -> hash of instances
my %classPredicates;	# Maps subject classes -> hash of predicates
foreach my $s (keys %subjectPredicates) {
	my @predicates = keys %{$subjectPredicates{$s}};
	foreach my $c (&TypesOf($s)) {
		# print "s: $s c: $c\n";
		$classInstances{$c}->{$s} = 1;
		foreach my $p (@predicates) {
			$classPredicates{$c}->{$p} = 1;
			}
		}
	}

print "===== Predicates by Subject Class =====\n";
my @sortedClasses = sort {&ShortenUri($a) cmp &ShortenUri($b)}
		keys %classInstances;
foreach my $c (@sortedClasses) {
	my $sc = &ShortenUri($c);
	my @instances = keys %{$classInstances{$c}};
	my $ni = scalar(@instances);
	print "$sc:$ni\n";
	my @sortedPredicates = sort {&ShortenUri($a) cmp &ShortenUri($b)}
			keys %{$classPredicates{$c}};
	foreach my $p (@sortedPredicates) {
		my $sp = &ShortenUri($p);
		print "  $sp -> { ";
		#### TODO: include the count of triples using this predicate
		my %oClasses;
		my @objects = keys %{$predicateObjects{$p}};
		foreach my $o (@objects) {
			my @types = &TypesOf($o);
			foreach my $t (@types) {
				$oClasses{$t}++;
				}
			}
		foreach my $c (sort keys %oClasses) {
			my $nc = $oClasses{$c};
			my $sc = &ShortenUri($c);
			$sc = "LIT:$sc" if $isDatatype{$c};
			print "$sc:$nc ";
			}
		my $no = scalar(@objects);
		print "}:$no\n";
		}
	print "\n";
	}

#### This list of predicates is no longer needed:
if (0) {
print "Predicates:  \n";
my @sortedPredicates = sort {&ShortenUri($a) cmp &ShortenUri($b)}
		keys %predicateSubjects;
foreach my $p (@sortedPredicates) {
	my $sp = &ShortenUri($p);
	print "  $sp: { ";
	my %sClasses;
	my @subjects = keys %{$predicateSubjects{$p}};
	foreach my $s (@subjects) {
		my @types = &TypesOf($s);
		# print "(TypesOf($s):@types) ";
		foreach my $t (@types) {
			$sClasses{$t}++;
			}
		}
	foreach my $c (sort keys %sClasses) {
		my $nc = $sClasses{$c};
		my $sc = &ShortenUri($c);
		$sc = "LIT:$sc" if $isDatatype{$c};
		print "$sc:$nc ";
		}
	my $ns = scalar(@subjects);
	print "}:$ns -> { ";
	my %oClasses;
	my @objects = keys %{$predicateObjects{$p}};
	foreach my $o (@objects) {
		my @types = &TypesOf($o);
		foreach my $t (@types) {
			$oClasses{$t}++;
			}
		}
	foreach my $c (sort keys %oClasses) {
		my $nc = $oClasses{$c};
		my $sc = &ShortenUri($c);
		$sc = "LIT:$sc" if $isDatatype{$c};
		print "$sc:$nc ";
		}
	my $no = scalar(@objects);
	print "}:$no\n";
	}
print "\n";
}

print "Namespaces for the above short names:\n";
foreach my $ns (sort keys %namespaces) {
	print "  $ns\n";
	}
exit 0;

######################## TypesOf ########################
# Look up the type of a subject (from global %typesOf) or default to UNK.
sub TypesOf
{
my $s = shift;
my @types = keys %{$typesOf{$s}};
return @types if @types;
return ( "UNK" );
}

######################## ShortenUri ########################
# Shorten the URI by stripping and remembering (in global %namespaces)
# the part before last slash or hash.
sub ShortenUri
{
my $uri = shift;
$uri = $uri->as_string() if RDF::Trine::Node->is_node();
$uri = $1 if $uri =~ m/^\<(.*)\>$/;
return $uri if $uri =~ m/^\"/ || $uri =~ m/\"$/;	# Ignore literals
return $uri if $uri !~ s/(^.*[\/\#])(.)/$2/;
my $ns = $1;
$namespaces{$ns} = 1;
return $uri;
}

