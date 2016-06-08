# rcfilechecks
This script compares a NetApp 7-mode running networking configuration against what is configured in the systems RC file.  The script compares both nodes in the HA pair, which it reads in from a file provided at the command line.

The script checks for the following:
Missing IPSpaces on controller
Extra IPspaces  on controller
IPspaces with different members between controllers
Missing Interfaces in RC file
Extra Interfaces in RC file
Missing VLAN Interfaces in RC file
Extra VLAN Interfaces in RC file
Missing VLANs in RC file
Extra VLANs in RC file
Non-matching partner name in RC file
Interfaces with no partner in the RC file

The output is in a CSV file in the directory the script is in by default.

Running Example
sh network-config-check.sh /tmp/controller-list

Controller List File Example
node1,node2
node3,node4
