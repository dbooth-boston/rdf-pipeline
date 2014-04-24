#! /bin/sh

# Set environment variables needed for testing RDF::Pipeline.

# Only the RDF_PIPELINE_DEV_DIR must be set manually.
# All others are (normally) set automatically by this script.
#
# RDF_PIPELINE_DEV_DIR must be set to the top development directory 
# for the RDF::Pipeline project (as checked out from github), which must
# contain the module directory "RDF-Pipeline".

export RDF_PIPELINE_DEV_DIR=/home/dbooth/rdf-pipeline/trunk

#################################################################
# All variables beyond this point are set automatically (unless
# something goes wrong).
#################################################################

# Set RDF_PIPELINE_WWW_DIR.  Use $DOCUMENT_ROOT if set, or look
# in the default Apache2 config file for the DocumentRoot definition.
if [ ! "$DOCUMENT_ROOT" ]
then
	APACHECONFIG="/etc/apache2/sites-enabled/000-default"
	DOCROOT=`expand "$APACHECONFIG" | grep '^ *DocumentRoot ' | sed 's/^ *DocumentRoot *//'`
	WORDCOUNT=`echo "$DOCROOT" | wc -w`
	if [ $WORDCOUNT = 1 ]
	then
		export DOCUMENT_ROOT="$DOCROOT"
	elif [ $WORDCOUNT = 0 ]
	then
		echo '[ERROR] DocumentRoot not found in' "$APACHECONFIG" 1>&2
	else
		echo '[ERROR] Multiple DocumentRoot definitions found in' "$APACHECONFIG": "$DOCROOT" 1>&2
	fi
fi
export RDF_PIPELINE_WWW_DIR="$DOCUMENT_ROOT"

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

