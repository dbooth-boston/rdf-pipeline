#! /usr/bin/perl -w

# Flush the caches and LMs.

my $wwwDir = $ENV{'RDF_PIPELINE_WWW_DIR'} or &EnvNotSet('RDF_PIPELINE_WWW_DIR');

my $qwww = quotemeta($wwwDir);
my $cmd = "rm -r $qwww/lm $qwww/cache ; mkdir $qwww/lm $qwww/cache ";
warn "$cmd\n";
`$cmd`;


########## EnvNotSet #########
sub EnvNotSet
{
@_ == 1 or die;
my ($var) = @_;
die "ERROR: Environment variable '$var' not set!  Please set it
by editing set_env.sh and then (in bourne shell) issuing the
command '. set_env.sh'\n";
}

