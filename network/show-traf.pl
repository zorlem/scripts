#!/usr/bin/perl -w
# a short script to make the output from "tc class show" greppable.
# One optional argument is accepeted - interface name
my %classes;

my $dev=$ARGV[0] || 'eth2';
my ($classid,$classrate,$classceil);
my ($sent, $dropped, $overlimit);
my $currate;
my ($lended, $borrowed);

open(TCSHOW, "tc -s class show dev $dev |");

while(<TCSHOW>) {
	if(($classid, $classrate, $classceil) = (/^class htb 1:(\d+).*rate (\d+[KMG]?bit) ceil (\d+[KMG]?bit)/)) {
		print "class: $classid, rate: $classrate, ceil: $classceil ";
		while(($_ = (<TCSHOW>)) !~ /^$/) {
			if(($sent, $dropped, $overlimit) = (/^\s+Sent (\d+) bytes.*dropped (\d+), overlimits (\d+)/)) {	
				print "sent: $sent, dropped: $dropped, overlimit: $overlimit ";
			} elsif (($currate) = (/^\s+rate (\d+[KMG]?bit)/)) {
				print "rate: $currate\n";
			}
		}
	} else {
		print $_;
	}
}
