# rcfilechecks
This script compares a NetApp 7-mode running networking configuration against what is configured in the systems RC file.  The script compares both nodes in the HA pair, which it reads in from a file provided at the command line.

The script checks for the following:
Missing IPSpaces on controller<br>
Extra IPspaces  on controller<br>
IPspaces with different members between controllers<br>
Missing Interfaces in RC file<br>
Extra Interfaces in RC file<br>
Missing VLAN Interfaces in RC file<br>
Extra VLAN Interfaces in RC file<br>
Missing VLANs in RC file<br>
Extra VLANs in RC file<br>
Non-matching partner name in RC file<br>
Interfaces with no partner in the RC file<br>

The output is in a CSV file in the directory the script is in by default.

Running Example

sh network-config-check.sh /tmp/controller-list

Controller List File Example
node1,node2<br>
node3,node4<br>
