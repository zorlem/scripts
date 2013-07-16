#!/usr/bin/perl -w

# Create a set of shaper files using Linux TC(8) for a list of networks

my $htbdir='/etc/sysconfig/htb/';
my $debug=0;

my %ifaces = ( 'eth1' => {'dir' => 'dst', 'match' => '16' },
            'eth2' => {'dir' => 'src', 'match' => '12' }
);

my @nets = ( '10.0.36.0/24', '10.11.122.0/23', '10.164.8.0/21'); 

my %userip;

foreach my $iface (keys %ifaces) {
        # clear
        print "filter del dev $iface parent 1:0 prio 100\n";
        # root filter
        print "filter add dev $iface parent 1: prio 100 handle 2: protocol ip u32 divisor 256\n";
        foreach my $net (@nets) {
                # hash table filter
                print "filter add dev $iface protocol ip parent 1: prio 100 u32 match ip $ifaces{$iface}{'dir'} $net hashkey mask 0x000000ff at $ifaces{$iface}{'match'} link 2:\n";
        }
}
opendir(HTBDIR, $htbdir) or die "Unable to open dir $htbdir: $!";

while(my $file=readdir(HTBDIR)){
        next if($file =~ /^\./);
        if(my($dev,$target,$ip,$type) = ($file =~ /^(eth[\d]+)-\d+:(\d+)\.(\d+\.\d+\.\d+\.\d+)(_\w+)?$/)) {
                if(defined $type && $type =~ /int/) {
                        # international filters should go before local
                        $type=0;
                } else {
                        # local filters should go after international
                        $type=1;
                }
                $userip{$ip}{$dev}[$type]=$target;
        } else {
                warn "Strange filename: $file\n" if $debug;
                next; 
        }
}
foreach my $ip (keys %userip) {
        my @net = split(/\./, $ip);
	my $hashbucket=sprintf("%x",$net[3]);
        foreach my $iface (keys %{$userip{$ip}}) {
#                print "tc filter add dev $iface protocol ip parent 1: prio 100 u32 ht 2: sample ip dst $ip/24 match ip " . $ifaces{$iface}{'dir'} . " $ip match ip tos 0x02 0xff flowid 1:$userip{$ip}{$iface}[0]\n";
#                print "tc filter add dev $iface protocol ip parent 1: prio 100 u32 ht 2: sample ip dst $ip/24 match ip " . $ifaces{$iface}{'dir'} . " $ip classid 1:$userip{$ip}{$iface}[1]\n";
                print "filter add dev $iface protocol ip parent 1: prio 100 u32 ht 2:$hashbucket match ip " . $ifaces{$iface}{'dir'} . " $ip match ip tos 0x02 0xff flowid 1:$userip{$ip}{$iface}[0]\n";
                print "filter add dev $iface protocol ip parent 1: prio 100 u32 ht 2:$hashbucket match ip " . $ifaces{$iface}{'dir'} . " $ip classid 1:$userip{$ip}{$iface}[1]\n";

        }
}
