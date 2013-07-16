#!/bin/perl -w
# tool to create HTB shapers and fast hash filters
# uses tc and batch mode for fast processing

use Data::Dumper;
use DBI;
use Config::General qw(ParseConfig);
use strict;

my $path="/var/fence2";

require("$path/etc/fence.conf");

# for tc "batch" mode set this to ''
my $tc='/sbin/tc';
my $block=2;
my $debug=0;
# step to increment the classid
my $idstep=5000;

my %config = ParseConfig("$path/etc/shapeman.conf");

# speed for each service. service 0 is for main shaper (root). first number is rate (min
# guaranteed), second number is ceil (max allowed).
my %speedsdown = ( '0' => { 'int' => [ 78000, 78000 ], 'peer' => [ 800000, 800000 ] },
                '1800' => { 'int' => [ 512, 3072 ], 'peer' => [ 10240, 20480 ] },
                '3000' => { 'int' => [ 1536, 6144 ], 'peer' => [ 20480, 40960 ] },
                '6000' => { 'int' => [ 3072, 9216 ], 'peer' => [ 25600, 51200 ] },
                '8000' => { 'int' => [ 5120, 13312 ], 'peer' => [ 30720, 56320 ] },
                '10000' => { 'int' => [ 6144, 15360 ], 'peer' => [ 40960, 66560 ] },
                '12000' => { 'int' => [ 8192, 20480 ], 'peer' => [ 61440, 87040 ] }
);

my %speedsup = ( '0' => { 'int' => [ 78000, 78000 ], 'peer' => [ 800000, 800000 ] },
                '1800' => { 'int' => [ 307, 1536 ], 'peer' => [ 10240, 20480 ] },
                '3000' => { 'int' => [ 512, 3072 ], 'peer' => [ 20480, 40960 ] },
                '6000' => { 'int' => [ 1024, 4096 ], 'peer' => [ 25600, 51200 ] },
                '8000' => { 'int' => [ 2048, 6144 ], 'peer' => [ 30720, 56320 ] },
                '10000' => { 'int' => [ 3072, 7168 ], 'peer' => [ 40960, 66560 ] },
                '12000' => { 'int' => [ 5120, 10240 ], 'peer' => [ 61440, 87040 ] }
);


#1800            0,5 - 3Mbit     0,3 - 1,5Mbit           10 - 20 Mbit    10 - 20 Mbit
#3000            1,5 - 6 Mbit    0,5 - 3 Mbit            20 - 40 Mbit    20 - 40 Mbit
#6000            3 - 9 Mbit      1 - 4 Mbit              25- 50 Mbit     25- 50 Mbit
#8000            5 - 13 Mbit     2 - 6 Mbit              30 - 55 Mbit    30 - 55 Mbit
#10000           6- 15 Mbit      3 - 7 Mbit              40 - 65 Mbit    40 - 65 Mbit
#12000           8 - 20 Mbit     5 - 10 Mbit             60 - 85 Mbit    60 - 85 Mbit
 

# define input and output interfaces. 'dir' is used for the filters, 'match' is the offset in the IP
# header for the specific byte to match on, 'speed' is a referrence to the shaper speeds
my %ifaces = ( 'eth1' => {'dir' => 'dst', 'match' => '16', 'speed' => \%speedsdown },
            'eth2' => {'dir' => 'src', 'match' => '12', 'speed' => \%speedsup }
);

my @nets = ( '10.0.36.0/24', '10.11.122.0/23', '10.164.8.0/21'); 

my %userip;

sub clearshaper($) {
        my $iface=shift;
        print "$tc qdisc del dev $iface root\n";
}

sub addmainfilter($) {
        my $iface=shift;
        print "$tc filter add dev $iface parent 1: prio 100 handle 2: protocol ip u32 divisor 256\n";
        foreach my $net (@nets) {
                # hash table filter
                print "$tc filter add dev $iface protocol ip parent 1: prio 100 u32 match ip $ifaces{$iface}{'dir'} $net hashkey mask 0x000000ff at $ifaces{$iface}{'match'} link 2:\n";
        }
}

sub addroot($) {
        my $iface=shift;
        # pointer to the speeds for the interface
        my $speed=$ifaces{$iface}{'speed'}->{'0'};
        print "$tc qdisc add dev $iface root handle 1 htb default 10\n";
        print "$tc class add dev $iface parent 1: classid 1:10 htb rate 256Kbit prio 5\n";
        print "$tc qdisc add dev $iface parent 1:10 handle 10 sfq perturb 10\n";
        warn("$iface: int " . $speed->{'int'}->[0] . '/' . $speed->{'int'}->[1] . 
                ' peer ' . $speed->{'peer'}->[0] . '/' . $speed->{'peer'}->[1]) if $debug;
        # main shapers - international, classid = 1:50
        print "$tc class add dev $iface parent 1: classid 1:50 htb rate " . $speed->{'int'}[0] . "Kbit ceil " . $speed->{'int'}[1] . "Kbit prio 5\n";
        # ... and peering, classid = 1:51
        print "$tc class add dev $iface parent 1: classid 1:51 htb rate " . $speed->{'peer'}[0] . "Kbit ceil " . $speed->{'peer'}[1] . "Kbit prio 5\n";
}

sub shapeuser($$) {
        my $userid=shift;
        my $shaper=shift;
        foreach my $iface (keys %ifaces) {
                my $speed=$ifaces{$iface}{'speed'}->{$shaper};
                my $i=0; # iterator for classid generation
        # international
                print "$tc class add dev $iface parent 1:50 classid 1:" . ($userid  + ($idstep*$i)) . ' htb rate ' . $speed->{'int'}[0] . 'Kbit ceil ' . $speed->{'int'}[1] . "Kbit prio 5\n";
                print "$tc qdisc add dev $iface parent 1:" . ($userid + ($idstep*$i)) . " handle " . ($userid + ($idstep*$i)) . " sfq perturb 10\n";
                $i++;
        # peering
                print "$tc class add dev $iface parent 1:51 classid 1:" . ($userid  + ($idstep*$i)) . ' htb rate ' . $speed->{'peer'}[0] . 'Kbit ceil ' . $speed->{'peer'}[1] . "Kbit prio 5\n";
                print "$tc qdisc add dev $iface parent 1:" . ($userid + ($idstep*$i)) . " handle " . ($userid + ($idstep*$i)) . " sfq perturb 10\n";
        }
}
        
sub getusers() {
        my ($vpnip,$shape,$username);
        # start of generated user ids
        my $id=100;
        my %users=();
        my $DSN = join(':',"DBI:mysql",$config{'db'}{'name'},$config{'db'}{'host'},$config{'db'}{'port'});
        my $stmt="SELECT vpnip,shape,username from nonstop where update_shaper=0 and block=$block";
        eval {
                my $dbh = DBI->connect($DSN, $config{'db'}{'user'}, $config{'db'}{'pass'}, {RaiseError=>1});
                # transform the array to a hash, vpnip is the key, shaper and username are the values
                my $sth=$dbh->prepare($stmt);
                $sth->execute;                
                $sth->bind_col(1, \$vpnip);
                $sth->bind_col(2, \$shape);
                $sth->bind_col(3, \$username);
                while($sth->fetchrow_arrayref) {
                        warn("$vpnip is already defined, ovewriting") if (exists $users{$vpnip});
                        $users{$vpnip} = [ $id++, $shape, $username];
                }
        };
        if($@) {
                die("Error reading users. Query: " . $DBI::lasth->{Statement} . ". Error: $@, " . $DBI::lasth->errstr)
        }
        return \%users;
}

sub filteruser($$) {
        my $i=1; # an iterator for calculating the classid based on $userid and $idstep
        my $ip=shift;
        my $userid=shift;
        my @net = split(/\./, $ip);
	my $hashbucket=sprintf("%x",$net[3]);
        foreach my $iface (keys %ifaces) {
                my $i=0; # an iterator for calculating the classid based on $userid and $idstep
                warn "step: $idstep, inc: $i, userid: $userid" if $debug;
                # order here is important. we want the more specific TOS filter to match first.
                print "$tc filter add dev $iface protocol ip parent 1: prio 100 u32 ht 2:$hashbucket match ip " . $ifaces{$iface}{'dir'} . " $ip match ip tos 0x02 0xff flowid 1:" . ($userid  + ($idstep*$i++)) . "\n";
                print "$tc filter add dev $iface protocol ip parent 1: prio 100 u32 ht 2:$hashbucket match ip " . $ifaces{$iface}{'dir'} . " $ip classid 1:" . ($userid + ($idstep*$i++)) . "\n";

        }
}

my $userip=getusers();
warn Dumper(%{$userip}) if $debug;

foreach my $iface (keys %ifaces) {
        clearshaper($iface);
        addroot($iface);
        addmainfilter($iface);
}
foreach my $ip (keys %{$userip}) {
        my @net = split(/\./, $ip);
	my $hashbucket=sprintf("%x",$net[3]);
        my ($userid,$service,$username)=@{$userip->{$ip}};
        unless (exists $speedsup{$service} and exists $speedsdown{$service}) {
                warn("Invalid shaper specified for $username: $service with IP $ip");
                next;
        }
        print('#user: ' . $username . " shape: " . $service. "\n");
        shapeuser($userid, $service);
        filteruser($ip, $userip->{$ip}->[0]);
}
