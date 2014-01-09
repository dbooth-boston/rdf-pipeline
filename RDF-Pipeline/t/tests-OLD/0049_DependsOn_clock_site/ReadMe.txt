Verify that a node that dependsOn a clock site (which cannot
be cached because it changes every time it is retrieved)
causes the node's updater to be fired on every request.

See issue 56:
http://code.google.com/p/rdf-pipeline/issues/detail?id=56

