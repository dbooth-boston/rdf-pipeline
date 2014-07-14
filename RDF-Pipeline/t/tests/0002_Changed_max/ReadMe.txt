OBSOLETE: The RDF Pipeline Framework used to only run a node's updater
once if a node has no inputs/dependsOn, but we have changed it to
fire the updater every time in this case.  Therefore, this test
is now disabled in testscript.

		-----------

This shows that :max's updater is not run after the first time, 
because it has no inputs/dependsOn.

