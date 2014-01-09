Generic SPARQL access.

This directory is for providing generic SPARQL server access via 
command-line scripts that access the server via HTTP.
Each subdirectory of scripts is named after a type of SPARQL server,
and holds server-specific scripts.  Each directory should include
the following scripts:

	sparql-select
	sparql-construct
	sparql-ask
	sparql-update

To use the correct scripts for the type of SPARQL server that you
wish to use, just set your $PATH to include the appropriate directory.

The following environment variable must also be set:

  SPARQL_SERVER		
	The base URI of your desired server.  Example:
	export SPARQL_SERVER=http://localhost:8080/openrdf-workbench/repositories/mda_v11

