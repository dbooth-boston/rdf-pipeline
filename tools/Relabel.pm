# RDF::Trine::Model::Relabel
# -----------------------------------------------------------------------------

# Copyright 2014 by David Booth
# This software is available as free and open source under
# the Apache 2.0 software license, which may be viewed at
# http://www.apache.org/licenses/LICENSE-2.0.html
# Code home: https://github.com/dbooth-boston/rdf-pipeline/

=head1 NAME

RDF::Trine::Model::Relabel - Relabel blank nodes in a model

****** UNFINISHED ********
I started writing this, using a package from Gregory Todd Williams
as a template, but didn't finish.
**************************

=head1 VERSION

This document describes RDF::Trine::Model::Relabel version 0.001

=head1 SYNOPSIS

  use RDF::Trine::Model::Relabel;
  
  my $model = RDF::Trine::Model->temporary_model();
  ...
  # Canonicalize blank nodes:
  $model->relabel();
  
=head1 DESCRIPTION

RDF::Trine::Model::Relabel is used to relabel blank nodes to a
canonical form.  It creates labels that are: (a) unique within the model; and (b) likely to be
the same whenever the model is relabeled, in spite of small changes to the
RDF data.  Thus, it is very useful in generating canonical RDF in ntriples
format,  by

- Relabel blank nodes in a model
RDF::Trine provides an Resource Descriptive Framework (RDF) with an emphasis on
extensibility, API stability, and the presence of a test suite. The package
consists of several components:

=over 4

=item * RDF::Trine::Model - RDF model providing access to a triple store. This module would typically be used to access an existing store by a developer looking to "Just get stuff done."

=item * RDF::Trine::Parser - RDF parsers for various serialization formats including RDF/XML, Turtle, RDFa, and RDF/JSON.

=item * RDF::Trine::Store::Memory - An in-memory, non-persistant triple store. Typically used for temporary data.

=item * RDF::Trine::Store::DBI - A triple store for MySQL, PostgreSQL, and SQLite, based on the relational schema used by Redland. Typically used to for large, persistent data.

=item * RDF::Trine::Iterator - Iterator classes for variable bindings and RDF statements, used by RDF::Trine::Store, RDF::Trine::Model, and RDF::Query.

=item * RDF::Trine::Namespace - A convenience class for easily constructing RDF::Trine::Node::Resource objects from URI namespaces.

=back

=cut

package RDF::Trine;

use 5.010;
use strict;
use warnings;
no warnings 'redefine';
use Module::Load::Conditional qw[can_load];

our ($debug, @ISA, $VERSION, @EXPORT_OK);
BEGIN {
	$debug		= 0;
	$VERSION	= '1.005';
	
	require Exporter;
	@ISA		= qw(Exporter);
	@EXPORT_OK	= qw(iri blank literal variable statement store UNION_GRAPH NIL_GRAPH);
	
	unless ($ENV{RDFTRINE_NO_REDLAND}) {
		can_load( modules => {
			'RDF::Redland'					=> undef,
			'RDF::Trine::Store::Redland'	=> undef,
			'RDF::Trine::Parser::Redland'	=> undef,
		} );
	}
}

use constant UNION_GRAPH	=> 'tag:gwilliams@cpan.org,2010-01-01:RT:ALL';
use constant NIL_GRAPH		=> 'tag:gwilliams@cpan.org,2010-01-01:RT:NIL';

use Log::Log4perl qw(:easy);
if (! Log::Log4perl::initialized() ) {
    Log::Log4perl->easy_init($ERROR);
}

use RDF::Trine::Graph;
use RDF::Trine::Parser;
use RDF::Trine::Serializer;
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Namespace;
use RDF::Trine::NamespaceMap;
use RDF::Trine::Iterator;
use RDF::Trine::Store;
use RDF::Trine::Error;
use RDF::Trine::Model;

use RDF::Trine::Parser::Turtle;
use RDF::Trine::Parser::TriG;


sub _uniq {
	my %seen;
	my @data;
	foreach (@_) {
		push(@data, $_) unless ($seen{ $_ }++);
	}
	return @data;
}

=head1 FUNCTIONS

=over 4

=item C<< iri ( $iri ) >>

Returns a RDF::Trine::Node::Resource object with the given IRI value.

=cut

sub iri {
	my $iri	= shift;
	return RDF::Trine::Node::Resource->new( $iri );
}

=item C<< blank ( $id ) >>

Returns a RDF::Trine::Node::Blank object with the given identifier.

=cut

sub blank {
	my $id	= shift;
	return RDF::Trine::Node::Blank->new( $id );
}

=item C<< literal ( $value, $lang, $dt ) >>

Returns a RDF::Trine::Node::Literal object with the given value and optional
language/datatype.

=cut

sub literal {
	return RDF::Trine::Node::Literal->new( @_ );
}

=item C<< variable ( $name ) >>

Returns a RDF::Trine::Node::Variable object with the given variable name.

=cut

sub variable {
	my $name	= shift;
	return RDF::Trine::Node::Variable->new( $name );
}

=item C<< statement ( @nodes ) >>

Returns a RDF::Trine::Statement object with the supplied node objects.

=cut

sub statement {
	my @nodes	= @_;
	if (scalar(@nodes) == 4) {
		return RDF::Trine::Statement::Quad->new( @nodes );
	} else {
		return RDF::Trine::Statement->new( @nodes );
	}
}

=item C<< store ( $config ) >>

Returns a RDF::Trine::Store object based on the supplied configuration string.
See L<RDF::Trine::Store> for more information on store configuration strings.

=cut

sub store {
	my $config	= shift;
	return RDF::Trine::Store->new_with_string( $config );
}

1; # Magic true value required at end of module
__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 SEE ALSO

L<http://www.perlrdf.org/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

