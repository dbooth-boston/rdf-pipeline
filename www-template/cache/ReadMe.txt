This "cache" directory holds dynamically generated cache files
for nodes in a pipeline.  These cache files may be safely deleted, 
with the understanding that deleting one will force the framework to
regenerate it (and likely others that are downstream of it).
Thus, one simple way to force the framework to regenerate all 
caches is just to delete this entire directory.

