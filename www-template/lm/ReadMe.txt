This "lm" directory contains: 

	(a) High-resolution "last modified" datetimes (with HTTP headers
	and ETag headers) for nodes and other objects that are used by
	the RDF Pipeline framework.  Each one is held in a file whose
	name is a URL-encoded URI.

	(b) A datetime and counter (in lmCounter.txt) that is used to
	generate unique high-resolution "last modified" datetimes.

If the RDF Pipeline is not currently running then these file can all
be safely deleted.  However, deleting them will force the Pipeline to
regenerate its caches.

