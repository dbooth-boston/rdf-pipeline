This tests tools/ste.perl to ensure that it detects a duplicate
template variable in the #inputs list:
#inputs( $inUri Bill ${Taft} $inUri )
It does not run a pipeline.

