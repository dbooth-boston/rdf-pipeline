Tests implicit updaters as determined by updaterFileExtensions,
specified in ont/ont.n3 .  Although the perl code basically works, 
as of this writing (5-May-2013) there is still a bug
(perhaps with the Apache configuration, or maybe mod_perl
needs to be used differently) that causes files like node/labs.txt
to be served directly by Apache instead of invoking our mod_perl
handler.  See issue 37:
http://code.google.com/p/rdf-pipeline/issues/detail?id=37

