Test a GraphNode going to a FileNode.  GraphNode data is serialized
as Turtle and passed to FileNode as Turtle.

NOTE: This test expects a Sesame repository at
http://localhost:28080/openrdf-workbench/repositories/owlimlite/
It will produce an error like the following if it is not there:
[[
/tmp/rdfp/0036_GraphNode_FileNode/actual-filtered/test/apacheError.log:[Sun Mar 04 21:34:09 2012] [error] [client 127.0.0.1] ERROR: Failed to deserialize /home/dbooth/rdf-pipeline/trunk/Private/www/cache/bill-presidents.ttl/serCache to http://localhost/cache/GraphNode/bill-presidents.ttl/cache with Content-Type: text/turtle\n
]]

Or the error might be an "HTTP/1.1 500 Internal Server Error" or
it may look like:
[[
> <title>500 Internal Server Error</title>
> </head><body>
> <h1>Internal Server Error</h1>
> <p>The server encountered an internal error or
> misconfiguration and was unable to complete
> your request.</p>
> <p>Please contact the server administrator,
]]

