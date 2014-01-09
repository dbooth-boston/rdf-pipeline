#! /usr/bin/perl -w 
package RDF::Pipeline::Template;

# RDF Pipeline Framework -- Template expansion.
# Copyright 2011 & 2012 David Booth <david@dbooth.org>
# Code home: http://code.google.com/p/rdf-pipeline/
# See license information at http://code.google.com/p/rdf-pipeline/ 

use 5.10.1; 	# It *may* work under lower versions, but has not been tested.
use strict;
use warnings;
use Carp;

require Exporter;
our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use RDF::Pipeline::Template ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(

			ScanAndAddInputs
			ScanAndAddOutputs
			ScanAndAddParameters
			ScanForList
			ScanAndAddEnvs
			AddPairsToHash
			ParseQueryString
			ExpandTemplate
			ProcessTemplate
			GetArgsAndProcessTemplate 

			) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
);

our $VERSION = '0.01';

#file:RDF-Pipeline/lib/RDF/Pipeline/Template.pm
#----------------------

use URI::Escape;

# Sparql Template Expander

##################################################################
###################           MAIN            ####################
##################################################################

unless (caller) {
  # print "This is the script being executed\n";
  &GetArgsAndProcessTemplate();
  exit 0;
}


##################################################################
###################         FUNCTIONS         ####################
##################################################################

################### ScanAndAddInputs ####################
# Called as: 
# ($template, $pHash) = 
#    &ScanAndAddInputs($template, $pValues, $pHash);
sub ScanAndAddInputs
{
return &ScanAndAddToHash("inputs", @_);
}

################### ScanAndAddOutputs ####################
# Called as: 
# ($template, $pHash) = 
#    &ScanAndAddOutputs($template, $pValues, $pHash);
sub ScanAndAddOutputs
{
return &ScanAndAddToHash("outputs", @_);
}

################### ScanAndAddToHash ####################
# Scan $template for a list of variables specified by the given $keyword,
# then add variable/value pairs to the given hashref, using that list 
# and the given list of values, which must be the same length.
# If no hashRef is given, a new one will be created.
# The hashref is returned.
sub ScanAndAddToHash
{
@_ <= 5 or confess "$0: ScanAndAddToHash called with too many arguments\n";
@_ >= 3 or confess "$0: ScanAndAddToHash called with too few arguments\n";
my ($keyword, $template, $pValues, $pHash) = @_;
$pHash ||= {};
my $pVars;
($template, $pVars) = &ScanForList($keyword, $template);
&AddPairsToHash($pVars, $pValues, $pHash);
return ($template, $pHash);
}

################### ScanAndAddParameters ####################
# Scan $template for a list of parameters, which is removed from
# the returned $template.  Then, to the given hashref,
# add the corresponding values from the given $queryString.
# In selecting the values from the $queryString, delimiters are
# stripped from the variables, using &BaseVar($_).
sub ScanAndAddParameters
{
@_ <= 3 or confess "$0: ScanAndAddParameters called with too many arguments\n";
@_ >= 1 or confess "$0: ScanAndAddParameters called with too few arguments\n";
my ($template, $queryString, $pHash) = @_;
$pHash ||= {};
$queryString ||= "";
my $pVars;
($template, $pVars) = &ScanForList("parameters", $template);
my $qsHash = &ParseQueryString($queryString);
my %pWanted = map 
	{
	my $value = $qsHash->{&BaseVar($_)};
	($_, defined($value) ? $value : "")
	} @{$pVars};
my $errorTemplate = "$0: ERROR: Duplicate template variable: %s\n";
foreach my $var (@{$pVars}) {
	die sprintf($errorTemplate, $var)
		if $errorTemplate && exists($pHash->{$var});
	$pHash->{$var} = $pWanted{$var};
	}
return ($template, $pHash);
}

################### ScanForList ####################
# Scan $template for a declared list of variable names, such as:
#	#inputs( $foo ${fum} )
# which is removed from the returned $template.  Also returns a list ref 
# of the variable names found in the declared list.
# The given $keyword should normally be "inputs", "outputs" or "parameters",
# but may be some other word.
sub ScanForList
{
@_ == 2 or confess "Bad args";
my $keyword = shift or confess "$0: ScanForList called with no keyword\n";
my $template = shift;
defined($template) or confess "$0: ScanForList called with undefined template\n";
my @inVars = ();
# Given keyword "inputs", the pattern matches the first line like:
#	#inputs( $foo ${fum} )
if ($template =~ s/^\#$keyword\(\s*([^\(\)]+?)\s*\)(.*)(\n|$)//m) {
	my $inList = $1;
	my $extra = $2;
	my $line = $&;
	# warn "FOUND inList: ($inList) extra: ($extra) line: ($line)\n";
	$extra =~ s/\A\s*//;
	### Do not allow trailing comment:
	### $extra =~ s/\A\#.*//;
	die "$0: ERROR: Extra text after \#$keyword(...): $extra\n" if $extra;
	push(@inVars, split(/\s+/, $inList));
	}
return ($template, \@inVars);
}

################### ScanAndAddEnvs ####################
# Scan $template for $ENV{foo} references and add each one (as a key)
# to the given hashref, where its value will be the value of that
# environment variable (or empty string, if not set).
# If no hashref is given, one will be created.
# The hashref is returned.  Existing values in the hashref will be
# silently overwritten if a duplicate key is used.
# The $template is not modified, and therefore not returned.
sub ScanAndAddEnvs
{
my $template = shift;
my $pEnvs = shift || {};
defined($template) or confess "$0: ScanAndAddEnvs called with undefined template\n";
my @vars = ($template =~ m/\$ENV\{(\w+)\}/gi);
# warn "env vars: @vars\n";
foreach (@vars) {
	$pEnvs->{"\$ENV{$_}"} = (defined($ENV{$_}) ? $ENV{$_} : "");
	}
# my @envs = %{$pEnvs};
# warn "envs: @envs\n";
return $pEnvs;
}

################### AddPairsToHash #####################
# Add pairs of corresponding values from the two arrayrefs to the
# given hashref.  If no hashref is given, a new one will be created.
# The hashref is returned.  
# An error will be generated if a duplicate key is seen.
sub AddPairsToHash
{
my ($pVars, $pVals, $pRep) = @_;
$pRep ||= {};
$pVars && $pVals or confess "$0: AddPairsToHash called with insufficient arguments\n";
my $nVars = scalar(@{$pVars});
my $nVals = scalar(@{$pVals});
$nVars >= $nVals or die "$0: ERROR: $nVals values provided for $nVars template variables (@{$pVars})\n";

my $errorTemplate = "$0: ERROR: duplicate template variable: %s\n";
for (my $i=0; $i<@{$pVars}; $i++) {
	die sprintf($errorTemplate, ${$pVars}[$i])
		if $errorTemplate && exists($pRep->{${$pVars}[$i]});
	my $val = ${$pVals}[$i];
	$val = "" if !defined($val);
	$pRep->{${$pVars}[$i]} = $val;
	}
return $pRep;
}

################### ParseQueryString ####################
# Create (or add to) a hashref that maps query string variables to values.
# Both variables and values are uri_unescaped.
# Example:
#   'foo=bar&fum=bif'  --> { 'foo'=>'bar', 'fum'=>'bif' }
# If there is a duplicate variable then the latest one silently
# takes priority.  If no hashref is given, a new one will be created.
# The hashref is returned.
sub ParseQueryString
{
my $qs = shift || "";
my $hashref = shift || {};
# Per http://www.w3.org/TR/1999/REC-html401-19991224/appendix/notes.html#h-B.2.2
# also allow semicolon to be treated as ampersand separator:
foreach ( split(/[\&\;]/, $qs) ) {
        my ($var, $val) = split(/\=/, $_, 2);
        $val = "" if !defined($val);
	$hashref->{uri_unescape($var)} = uri_unescape($val) if $var;
	}
return $hashref;
}

################# BaseVar ####################
# Given a string like '${foo}' (representing a declared variable), 
# return a new string with the delimiters stripped off: 'fum'.
# This is for variables that are used as query string parameters,
# such as: http://example/whatever?foo=bar
# For simplicity, variable names must match \w+ .
sub BaseVar
{
my $dv = shift or confess "Bad args";
$dv =~ m/^\W*(\w+)\W*$/ or confess "$0: Bad template variable in #parameters(...): $dv\n";
my $baseVar = $1;
return $baseVar;
}

################### ExpandTemplate ####################
# Expand the given template, substituting variables for values.
# Variable/value pairs are provided in the given hashref.
sub ExpandTemplate
{
@_ == 2 or confess "Bad args";
my ($template, $pRep) = @_;
defined($template) or return undef;
# Make a pattern to match all formals:
my $pattern = join(")|(", 
	# Ensure that words aren't run together:
	# \$foo --> \$foo\b ;  foo --> \bfoo\b
	map {s/\A(\w)/\\b$1/; s/(\w)\Z/$1\\b/; $_}  
	map {quotemeta($_)} keys %{$pRep});
# warn "pattern: (($pattern))\n";
# Do the replacement and return the result:
$template =~ s/(($pattern))/$pRep->{$1}/eg 
	if defined($pattern) && length($pattern) > 0;
return $template;
}

##################### ProcessTemplate #######################
# Scan and expand a template containing variable declarations like:
#	#inputs( $in1 ${in2} )
#	#outputs( {out1} [out2] )
# 	#parameters( $foo ${fum} )
# $queryString supplies values for variables declared as "#parameters",
# such as: foo=bar&fum=bif&foe=bah 
# Environment variables will also be substituted where they occur
# like $ENV{foo}, though if $thisUri is set then it will be used as the 
# value of $ENV{THIS_URI} regardless of what was set in the environment.
# $pInputs and $pOutputs are array references supplying values
# for declared "#inputs" and "#outputs".
# The function dies if duplicate declared variables are detected.
sub ProcessTemplate
{
@_ >= 1 && @_ <= 6 or confess "Bad args";
my ($template, $pInputs, $pOutputs, $queryString, $thisUri) = @_;
defined($template) or confess "Bad args";
$pInputs ||= {};
$pOutputs ||= {};
$queryString ||= "";
# Scan for $ENV{foo} vars:
my $pRep = &ScanAndAddEnvs($template);
# $thisUri (if set) takes precedence:
$pRep->{'$ENV{THIS_URI}'} = $thisUri if defined($thisUri);
# Scan for input, output and parameter vars and add them:
($template, $pRep) = 
	&ScanAndAddInputs($template, $pInputs, $pRep);
($template, $pRep) = 
	&ScanAndAddOutputs($template, $pOutputs, $pRep);
($template, $pRep) = 
	&ScanAndAddParameters($template, $queryString, $pRep);
# Expand the template and we're done:
my $result = &ExpandTemplate($template, $pRep);
return $result;
}

################### GetArgsAndProcessTemplate ###################
sub GetArgsAndProcessTemplate 
{
my @ins = ();
my @outs = ();
my @params = ();
my $thisUri = undef;
use Getopt::Long;
GetOptions(	
		"inputs|i=s" => \@ins,
		"outputs|o=s" => \@outs,
		"parameters|p=s" => \@params,
		"thisUri|t=s" => \$thisUri,
                ) or die "$0: Error reading options.\n";
$ENV{QUERY_STRING} = join("&", map { s/^[&;]+//; s/[&;]+$//; $_} @params)
	if @params;
my $params = $ENV{QUERY_STRING} || "";
$ENV{THIS_URI} = $thisUri if defined($thisUri);
$thisUri = $ENV{THIS_URI} || "";

my $template = join("", <>);

# warn "ins: @ins\n";
# warn "outs: @outs\n";

my $result = &ProcessTemplate($template, \@ins, \@outs, $params, $thisUri);

# Output the result:
print $result;
exit 0;
}

####################### Usage #######################
sub Usage
{
warn @_ if @_;
die "Usage: $0 [template] [ -i iVal1 ...] [ -o oVal1 ...] [ -p pVar1=pVal1 ...]
" . 'Arguments:
  template	
	Filename of SPARQL template to use instead of stdin.

Options:
  -i iVal1 ...		
	Values to be substituted into variables specified
	by "#inputs( $iVar1 ... )" line in template.

  -o oVal1 ...		
	Values to be substituted into variables specified
	by "#outputs( $oVar1 ... )" line in template.

  -p pVar1=pVal1 ...	
	URI encoded variable/value pairs to be substituted
	into variables specified by "#parameters( $pVar1 ... )"
	line in template.  Both variables and
	values will be uri_unescaped before use.  Multiple
	variable/value pairs may be specified together using
	"&" as separator: foo=bar&fum=bah&foe=bif .  If -p
	option is not used, then URI-encoded variable/value
	pairs will be taken from the QUERY_STRING environment
	variable, which is ignored if -p is used.

  -t thisUri
	Causes thisUri to be substituted for $ENV{THIS_URI}
	in template, overriding whatever value was set in 
	the environment.
';
}


##### DO NOT DELETE THE FOLLOWING TWO LINES!  #####
1;
__END__

=head1 NAME

RDF::Pipeline::Template - Perl extension for very simple template substitution.

=head1 SYNOPSIS

From the command line:

  ste.perl [options...] [template] 

with typical options (explained more fully below):
 -i iVal1 	Provide #inputs value iVal1
 -o oVal1 	Provide #outputs value oVal1
 -p pVar1=pVal1 Set QUERY_STRING to pVar1=pVal1

Or for use as a module, by a perl program:

  use RDF::Pipeline::Template qw( :all );
  my $result = &ProcessTemplate($template, \@ins, \@outs, 
		$queryString, $thisUri);

=head1 DESCRIPTION

This page documents both the RDF::Pipeline::Template module and
ste.perl, which is a tiny shell script that merely invokes
the module.

This module provides a very simple template processing facility.
It was intended primarily for writing SPARQL query templates for use
in the context of the RDF Pipeline Framework, but can be used for other
things.  It knows nothing about SPARQL syntax.

The template to be processed is either: (a) read from a file
specified on the command line; (b) read from stdin; or (c)
supplied directly as a string argument to &ProcessTemplate.

Template processing involves replacing template variables with 
values, which may be arbitrary strings.  No looping, conditional or
other features are provided.  Template variables include
those that are declared explicitly, as described next, and environment
variables, described later.

=head2 Declaring Template Variables

Template variables are declared within a template using lines like this:

  #inputs( iVar1 iVar2 ... iVarN )
  #outputs( oVar1 oVar2 ... oVarN )
  #parameters( pVar1 pVar2 ... pVarN )

This declares variables iVar1 ... iVarN, oVar1 ... oVarN and pVar1 ... pVarN
for use within the template.  Values may be provided when the template is
processed, as explained later.
Each of these
lines is optional and is removed when the template is processed.

The hash (#) MUST be the first character of the line, and there must
be no space between #inputs, #outputs or #parameters and the open
parenthesis .  Whitespace is
required between variable names, and is 
optional between the parentheses and the variables.
Variable names specified in #inputs or #outputs can use any syntax 
except whitespace or parentheses, i.e., they must
match the following Perl regular expression
(where \s is any whitespace):

  [^()\s]+

However, common variable syntax conventions like $foo , ${foo} or %foo% are a 
good idea for both safety and readability.   On the other hand, you could use a
string like http://example/var# as a variable name, which would
give you the effect of replacing that string throughout your template
when the template is processed.

The #inputs and #outputs directives have exactly the same function unless
you are using the RDF Pipeline Framework, in which case #inputs is
used to specify a node's inputs and #outputs specifies its outputs.

The syntax of #parameters variables is further restricted because of
the way they are set (via query string parameters, as described
below).  #parameters variables must be composed of "word" characters, 
optionally surrounded by non-"word" characters, i.e., they must match the
following Perl regular expression 
(where \w means [0-9a-zA-Z_]):

  [^()\s\w]*\w+[^()\s\w]*

The non-word characters are ignored when looking for the corresponding
query string variable, as further described below, so ${foo} and %foo% 
both correspond to query string variable foo.

=head2 Value Substitution

When a template is processed, values are substituted for all #inputs,
#outputs, #parameters and environment variables
that appear in the template, as described below.  If a value is not supplied
for a variable, then the empty string is silently substituted.

The template processor has no idea what you are
intending to generate, and values may be any text 
(limited in size only by memory),
so for the most part this is blind text substitution.

WARNING: If you are using this template system to generate 
queries, commands, HTML or
anything else that could be dangerous if inappropriate text were
injected, then you should be careful to scrub your values
before invoking this template processor.

Also, although bare words (or numbers!) are allowed as 
variable names, they are usually not a good idea, because it is too easy
to make a mistake like writing the following:

  #inputs( givenName )
  SELECT *
  WHERE { ?name foaf:givenName "givenName" }

which, when givenName has the value "Bill", will silently become:

  SELECT *
  WHERE { ?name foaf:Bill "Bill" }

which is probably NOT what you intended.

There is one small exception to this blind substitution:
the template processor will not break a word in the template.  
This means that you
can safely use a variable name like $f without fear that it will be 
substituted into template text containing the string $fred.  
Specifically, a variable beginning or ending with a Perl "word" character
[a-zA-Z0-9_] will have the Perl regular expression assertion \b (see
http://perldoc.perl.org/perlre.html#Assertions )
prepended or appended (or both) to
the substitution pattern, thus forcing the match to
only occur on a word boundary.
Template processing can, however, cause words to be joined together.
For example, if template variable ${eff} has the value PH , 
then a template string "ELE${eff}ANT" will become "ELEPHANT".

=head2 Supplying Values for Template Variables

The way to supply a value for a template variable depends on what kind
of template variable it is. 

=over

=item #inputs or #outputs variables

Any #inputs or #outputs variables are set using the -i or -o command-line options, 
respectively, or passed in array references if you are calling
&ProcessTemplate directly from Perl.  Values are supplied positionally: the 
value specified by the nth -i option (or -o option) is bound to the 
nth #inputs (or #outputs) variable, respectively.

=item #parameters variables

By default #parameters variables are set through the $QUERY_STRING environment
variable, which is assumed to provide an ampersand-delimited list of 
key=value pairs.
Per http://www.w3.org/TR/1999/REC-html401-19991224/appendix/notes.html#h-B.2.2
a semicolon can also be used as a delimiter instead of ampersand.
Both keys and values are URI decoded during template processing, i.e.,
any %-encodings are decoded.

Non-word characters (i.e., [^a-zA-Z0-9_]) in a #parameters variable 
are ignored when looking
up the corresponding key in the $QUERY_STRING.  For example,
parameters $min and ${max} that are declared in a template as:

  #parameters( $min ${max} )
  . . . 
  FILTER( ?n >= $min && ?n <= ${max} )

correspond to keys min and max in a $QUERY_STRING such as min=2&max=99 ,
yielding the following result:

  . . . 
  FILTER( ?n >= 2 && ?n <= 99 )

Parameter variables may also be set via the -p command-line option, 
which sets the QUERY_STRING environment variable (explained below).

If you are calling &ProcessTemplate directly from Perl, then parameter
values are supplied in a $queryString argument as a string, which has the exact
same syntax as the $QUERY_STRING.

If you specify the same variable name twice, such as in min=2&max=99&min=5 , 
the earlier value will be silently ignored, so $min will be 5.

=back 

=head2 ACCESSING ENVIRONMENT VARIABLES

In addition to any #inputs, #outputs or #parameters variables that you 
declare explicitly as described above, a template can access the values
of environment variables, using a fixed syntax.

=over

=item $ENV{VAR}

For any environment variable $VAR, $ENV{VAR} will be replaced with 
the value of the $VAR environment variable (if set)
or the empty string (if unset).

=item $ENV{QUERY_STRING}

This is a special case of $ENV{VAR}.  $ENV{QUERY_STRING}
will be replaced with the value of the $QUERY_STRING environment variable
(if set) or the empty string (if unset).   This is useful if you need
access to the raw $QUERY_STRING.  Normally it is not needed, 
because #parameters variables are set from the $QUERY_STRING environment
variable.  See the -p option of ste.perl.

=item $ENV{THIS_URI}

This is another special case of $ENV{VAR}.  $ENV{THIS_URI}
will be replaced with the value of the $THIS_URI environment variable
(if set) or the empty string (if unset).   See the -t option of ste.perl.

=back

=head2 EXAMPLE

Here is a complete template example, sample-template.txt, that illustrates
the features:

  #inputs( $inUri Bill ${Taft} )     
  #outputs( $outUri )
  #parameters( $max $min )
  Testing inputs, outputs:
    inUri: $inUri
    B_i_l_l: Bill  "Bill"  money@Bill.me
    Taft: ${Taft}
  Testing parameters (either from QUERY_STRING or from -p option):
    min: $min
    max: $max
  Testing environment variables:
    THIS_URI: $ENV{THIS_URI}
    FOO: $ENV{FOO}
  Testing the QUERY_STRING:
    $ENV{QUERY_STRING}
  Note that the following are NOT changed, because template 
  processing will NOT break words, and it is case sensitive:
    $inUriExtra  Billion  EmBill bill

If this template is processed using the following shell commands:

  export QUERY_STRING='min=2&max=99'
  ./ste.perl sample-template.txt -t http://example/this -i http://example/in -i William -i Taffy -o http://example/out

then the following result will be written to STDOUT:

  Testing inputs, outputs:
    inUri: http://example/in
    B_i_l_l: William  "William"  money@William.me
    Taft: Taffy
  Testing parameters (either from QUERY_STRING or from -p option):
    min: 2
    max: 99
  Testing environment variables:
    THIS_URI: http://example/this
    FOO:
  Testing the QUERY_STRING:
    min=2&max=99
  Note that the following are NOT changed, because template
  processing will NOT break words, and it is case sensitive:
    $inUriExtra  Billion  EmBill bill

=head2 EXPORT

None by default.

=head1 COMMAND LINE OPTIONS

When this module is run from the command line (as ste.perl) 
it has the following options:

=over

=item  -i iValueN

Provides a value for an #inputs variable.
This option should be repeated once for each variable
in the #inputs list: the nth -i option supplies
the value for the nth #inputs variable.
For example, given two variables $x and $y:

  #inputs( $x $y )

to set $x to 5 and $y to 10, the -i option should be used twice:

  ste.perl -i 5 -i 10

=item  -o iValueN 

Like the -i option, but for #outputs variables.

=item  -p pVar1=pVal1&pVar2=pVal2 ...

Sets the QUERY_STRING environment variable to provide
URI encoded key/value pairs to be substituted
into variables specified by the "#parameters( $pVar1 $pVar2 ... )"
line in template.  Both keys and
values will be uri_unescaped before variable substitution.  Multiple
key=value pairs may be specified together using
"&" or ";" as separator, such as: foo=bar&fum=bah&foe=bif .  
If the -p option is not used, then URI-encoded variable/value
pairs will be taken from the QUERY_STRING environment
variable.
This option may be repeated, in which case the given key=value
pairs will be concatenated into a single $QUERY_STRING,
with ampersand as a separator. 
Variable order is not significant unless the same
variable appears more than once in $QUERY_STRING, 
in which case the last value is silently used.

=item  -t thisUri

Sets the THIS_URI environment variable to thisUri,
which causes thisUri to be substituted for $ENV{THIS_URI}
in template.

=back

=head1 SEE ALSO

RDF Pipeline Framework: http://code.google.com/p/rdf-pipeline/ 

=head1 AUTHOR

David Booth <david@dbooth.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2011 & 2012 David Booth <david@dbooth.org>
See license information at http://code.google.com/p/rdf-pipeline/ 

=cut

