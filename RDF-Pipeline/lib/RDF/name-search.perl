#! /usr/bin/perl -w

# Throw-away script to search for particular names that need to be changed.

my @ignores = qw( 
	outUri
	);
my %ignores = map {($_, 1)} @ignores;

my @lines = <>;
for (my $i=1; $i<=@lines; $i++) {
	my $line = $lines[$i-1];
	$line =~ s/\bfigure\s+out\b/ /ig;
	# if ($lines[$i-1] =~ m/\b[a-zA-Z]+Uri\b/ && !$ignores{$&}) {
	# if ($lines[$i-1] =~ m/\b[a-zA-Z]*Name[a-zA-Z]*\b/ && !$ignores{$&}) {
	# Look for any match in this line:
	my $match = "";
	while ($line =~ s/(([a-zA-Z]*O)|(\bo))ut(([A-Z][a-zA-Z0-9_]*)|\b)/ /)
		{
		$match = $& if !$ignores{$&};
		}
	if ($match) {
		print "$i $match : $lines[$i-1]\n";
		# print "$match\n";
		}
	}

