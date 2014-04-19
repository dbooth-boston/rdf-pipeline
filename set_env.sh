#! /bin/sh

# Set environment variables needed for testing RDF::Pipeline.
# These should be customized for your installation.

# Apache DOCUMENT_ROOT for RDF-Pipeline:
export RDF_PIPELINE_WWW_DIR=/home/dbooth/rdf-pipeline/Private/www

# Top development directory for the RDF::Pipeline project, which must
# contain the module directory "RDF-Pipeline", and the module
# directory must contain the test directory "t":
export RDF_PIPELINE_DEV_DIR=/home/dbooth/rdf-pipeline/trunk

# Perl library path:
export PERL5LIB="$PERL5LIB:$RDF_PIPELINE_DEV_DIR/RDF-Pipeline/lib"

# Add test utilities to $PATH:
export PATH="$PATH:$RDF_PIPELINE_DEV_DIR/RDF-Pipeline/t"
export PATH="$PATH:$RDF_PIPELINE_DEV_DIR/RDF-Pipeline/t/helpers"

# Add tools utilities to $PATH:
export PATH="$PATH:$RDF_PIPELINE_DEV_DIR/tools"

# Add generic sparql utilities to path (initially sesame,
# but eventually should become generic):
export PATH="$PATH:$RDF_PIPELINE_DEV_DIR/tools/gsparql/scripts/sesame2_6"

