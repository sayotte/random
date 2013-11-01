#!/usr/bin/perl

use warnings;
use strict;

my ($timestamp, $hostname, $facility, $logcontent, $requested_ip, $requesting_mac, $via, $network, $reason);

# Timestamp
my $ts_re = '\w{3}+\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}';
# Hostname
my $hn_re = '\w+';
# Facility
my $fc_re = '[^:]+';
# IP Address
my $ip_re = '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';
# Network w/ CIDR mask
my $net_re = $ip_re . '/\d{1,2}';
# MAC address
my $mac_re = '[0-9a-fA-F]{1,2}:[0-9a-fA-F]{1,2}:[0-9a-fA-F]{1,2}:[0-9a-fA-F]{1,2}:[0-9a-fA-F]{1,2}:[0-9a-fA-F]{1,2}';

while(<STDIN>)
{
    if(! m/dhcpd:/){ next; }

    if(! m/($ts_re)\s($hn_re)\s($fc_re+):\s(.+)/)
    {
        print "Malformed: $_";
        next;
    }

    ($timestamp = $_) =~ s/($ts_re)\s.+/$1/;
    chomp($timestamp);
    s/$timestamp\s(.+)/$1/;

    ($hostname = $_) =~ s/($hn_re)\s.+/$1/;
    chomp($hostname);
    s/$hostname\s(.+)/$1/;

    ($facility = $_) =~ s/($fc_re):\s.+/$1/;
    chomp($facility);
    s/$facility:\s(.+)/$1/;

    $logcontent = $_;

    if(!m/DHCPNAK/ and !m/no free leases/)
    {
        next;
    }
    print "-------------------------------------------------------------------------------\n";
    print "Timestamp: $timestamp\n";
    print "Hostname: $hostname\n";
    print "Facility: $facility\n";
#    print "Log content: $logcontent";

    if(m/DHCPNAK/)
    {
    
        ($requested_ip = $_) =~ s/DHCPNAK on ($ip_re)\s.+/$1/;
        chomp($requested_ip);
        s/DHCPNAK on $requested_ip (.+)/$1/;
    
        ($requesting_mac = $_) =~ s/to ($mac_re) .+/$1/;
        chomp($requesting_mac);
        s/to $requesting_mac (.+)/$1/;
    
        ($via = $_) =~ s/via (\w+)/$1/;
        chomp($via);
    
        print "Requested IP: $requested_ip\n";
        print "Requesting MAC: $requesting_mac\n";
        print "Via: $via\n";
    }
    elsif(m/DHCPDISCOVER/ and m/no free leases/)
    {
        ($requesting_mac = $_) =~ s/DHCPDISCOVER from ($mac_re) .+/$1/;
        chomp($requesting_mac);
        s/DHCPDISCOVER from $requesting_mac\s+(.+)/$1/;

        ($via = $_) =~ s/via ([^:]+): .+/$1/;
        chomp($via);
        s/via $via:\s+(.+)/$1/;
        
        ($network = $_) =~ s/network ($net_re): .+/$1/;
        chomp($network);
        s/network $network:\s+(.+)/$1/;

        $reason = $_;

        print "Requesting MAC: $requesting_mac\n";
        print "Via: $via\n";
        print "On network: $network\n";
        print "Reason: $reason\n";
    }
}
