#!/bin/sh

#  network-config-check.sh
#  
#
#  Created by Matthew Shearer on 10/24/14.
#

SCRIPTDIR=/Users/mshearer/scripts/NetApp/CTL/7-mode
RIGHTNOW=$(date +%Y-%m-%d-%H%M)
CONTROLLERLIST=$1
OUTPUTFILE=$SCRIPTDIR/RC-CHECK-$RIGHTNOW.csv

#Start creation of output file
create_outputfile()
{
    echo "File Created: $RIGHTNOW" > $OUTPUTFILE
    echo "Controller Name,Missing IPSpaces on controller,Extra IPspaces  on controller,IPspaces with different members between controllers,Missing Interfaces in RC file,Extra Interfaces in RC file,Missing VLAN Interfaces in RC file,Extra VLAN Interfaces in RC file,Missing VLANs in RC file,Extra VLANs in RC file,Non-matching partner name in RC file,Interfaces with no partner in the RC file" >> $OUTPUTFILE
} #End creation of output file

#Start look at the IPspaces in use on the vFilers and compare to what exists on each controller
check_ipspaces()
{
    #create temporary files
    vfileripspaces=/tmp/vfileripspaces
    controller1ipspaces=/tmp/controller1ipspaces
    controller2ipspaces=/tmp/controller2ipspaces

    #get a list of the ipspaces in use in the vfilers
    cat $VFILERSFILE1 $VFILERSFILE2 | grep ipspace | grep -v default-ipspace | sort -u | awk '{print $2}' > $vfileripspaces
    #get a list of the ipspaces created on each controller
    cat $IPSPACESFILE1 | grep -v "Number of ipspaces configured" | awk '{print $1}' | grep -v default-ipspace | sort -u > $controller1ipspaces
    cat $IPSPACESFILE2 | grep -v "Number of ipspaces configured" | awk '{print $1}' | grep -v default-ipspace | sort -u > $controller2ipspaces

    #compare the ipspaces in use to the ones created on each controller and determine if any in use do not exist
    missingipspacesc1=$(comm -23 $vfileripspaces $controller1ipspaces | tr '\n' ';')
    missingipspacesc2=$(comm -23 $vfileripspaces $controller2ipspaces | tr '\n' ';')
    #compare the ipspaces in use to the ones created on each controller and determine if any exist on the controller but are not in use in the vfilers
    extraipspacesc1=$(comm -13 $vfileripspaces $controller1ipspaces | tr '\n' ';')
    extraipspacesc2=$(comm -13 $vfileripspaces $controller2ipspaces | tr '\n' ';')

    #remove temporary files
    rm $vfileripspaces
    rm $controller1ipspaces
    rm $controller2ipspaces
} #End look at the IPspaces in use on the vFilers and compare to what exists on each controller

#Start look at the IPspaces in use on the vFilers and compare to what exists on each controller
check_ipspace_members()
{
    #create temporary files
    vfileripspacelist=/tmp/vfileripspacemembers
    controller1ipspacemembers=/tmp/controller1ipspacemembers
    controller2ipspacemembers=/tmp/controller2ipspacemembers

    #get a list of the ipspaces in use in the vfilers
    cat $VFILERSFILE1 $VFILERSFILE2 | grep ipspace | grep -v default-ipspace | sort -u | awk '{print $2}' > $vfileripspacelist
    #get a list of the ipspace members based on what is in use by the vfilers
    cat $IPSPACESFILE1 | grep -v "Number of ipspaces configured" | awk '{print $1}' | grep -v default-ipspace | sort -u > $controller1ipspacemembers
    cat $IPSPACESFILE2 | grep -v "Number of ipspaces configured" | awk '{print $1}' | grep -v default-ipspace | sort -u > $controller2ipspacemembers

    #main variable for the list of ipspaces with member mismatches
    missingipspacemembersc1full=""
    missingipspacemembersc2full=""

    #loop through each ipspace in use and figure out if any members are missing
    for IPSPACE in $(cat $vfileripspacelist)
    do
        #get a list of the ipspace members
        grep -E '(^|\s)'$IPSPACE'($|\s)' $IPSPACESFILE1 | sed 's/.*(//' | sed 's/)//' | sed 's/vif[0-9]/vif/g' | tr " " "\n" | sort > $controller1ipspacemembers
        grep -E '(^|\s)'$IPSPACE'($|\s)' $IPSPACESFILE2 | sed 's/.*(//' | sed 's/)//' | sed 's/vif[0-9]/vif/g' | tr " " "\n" | sort > $controller2ipspacemembers

        #compare the members between the two controllers and determine if they do not match
        missingipspacemembersc1="$(comm -23 $controller1ipspacemembers $controller2ipspacemembers | tr '\n' ';')"
        missingipspacemembersc2="$(comm -13 $controller1ipspacemembers $controller2ipspacemembers | tr '\n' ';')"

        #add to the list if it is not empty
        if [[ -n "$missingipspacemembersc1" ]]
        then
            missingipspacemembersc1full="$missingipspacemembersc1full;$IPSPACE-$missingipspacemembersc1"
        fi
        if [[ -n "$missingipspacemembersc2" ]]
        then
            missingipspacemembersc2full="$missingipspacemembersc2full;$IPSPACE-$missingipspacemembersc2"
        fi #add to the list if it is not empty
    done #loop through each ipspace in use and figure out if any members are missing

    #remove temporary files
    rm $vfileripspacelist
    rm $controller1ipspacemembers
    rm $controller2ipspacemembers
} #End look at the IPspaces in use on the vFilers and compare to what exists on each controller

#Start look at the interfaces in use on the vFilers and compare to what exists in each controllers RC file
check_interfaces()
{
    #create temporary files
    vfilerinterfaces=/tmp/vfilerinterfaces
    controller1interfaces=/tmp/controller1interfaces
    controller2interfaces=/tmp/controller2interfaces
    vfilervlans=/tmp/vfilervlans
    controller1vlans=/tmp/controller1vlans
    controller2vlans=/tmp/controller2vlans

    #get a list of the interfaces in use on the vfilers
    cat $VFILERSFILE1 $VFILERSFILE2 | grep "IP address" | grep -v e0M | awk '{print $4}' | sed 's/\[//' | sed 's/\]//' | sort -u > $vfilerinterfaces
    #get a list of the vlans in use on the vfilers
    cat $VFILERSFILE1 $VFILERSFILE2 | grep "IP address" | grep -v e0M | awk '{print $4}' | sed 's/\[//' | sed 's/\]//' | sed 's/vif.*-//' | sort -u > $vfilervlans

    #get a list of the interfaces and vlans on the controller
    cat $RCFILE1 | grep ifconfig | grep -v e0M | awk '{print $2}' | sort > $controller1interfaces
    cat $RCFILE1 | grep ifconfig | awk '{print $2}' | grep "-" | sed 's/vif.*-//' | sort -u > $controller1vlans
    cat $RCFILE2 | grep ifconfig | grep -v e0M | awk '{print $2}' | sort | sort -u > $controller2interfaces
    cat $RCFILE2 | grep ifconfig | awk '{print $2}' | grep "-" | sed 's/vif.*-//' | sort -u > $controller2vlans

    missinginterfacesc1=$(comm -23 $vfilerinterfaces $controller1interfaces | grep -v vif[0-9] | tr '\n' ';')
    missinginterfacesc2=$(comm -23 $vfilerinterfaces $controller2interfaces | grep -v vif[0-9] | tr '\n' ';')
    extrainterfacesc1=$(comm -13 $vfilerinterfaces $controller1interfaces | grep -v vif[0-9] | tr '\n' ';')
    extrainterfacesc2=$(comm -13 $vfilerinterfaces $controller2interfaces | grep -v vif[0-9] | tr '\n' ';')

    missingvlansc1=$(comm -23 $vfilervlans $controller1vlans | tr '\n' ';')
    missingvlansc2=$(comm -23 $vfilervlans $controller2vlans | tr '\n' ';')
    extravlansc1=$(comm -13 $vfilervlans $controller1vlans | tr '\n' ';')
    extravlansc2=$(comm -13 $vfilervlans $controller2vlans | tr '\n' ';')

    #remove temporary files
    rm $vfilerinterfaces
    rm $controller1interfaces
    rm $controller2interfaces
    rm $vfilervlans
    rm $controller1vlans
    rm $controller2vlans
} #End look at the interfaces in use on the vFilers and compare to what exists in each controllers RC file

#Start look at the vlans in use on the vFilers and compare to what exists in each controllers RC file
check_vlans()
{
    #create temporary files
    vfilerrcvlans=/tmp/vfilervlans
    controller1rcvlans=/tmp/controller1vlans
    controller2rcvlans=/tmp/controller2vlans

    cat $VFILERSFILE1 $VFILERSFILE2 | grep "IP address" | grep -v e0M | awk '{print $4}' | sed 's/\[//' | sed 's/\]//' | sed 's/vif.*-//' | sort -u > $vfilerrcvlans
    c1vlanlist=$(cat $RCFILE1 | grep vlan | awk '{print substr($0, index($0, $4))}')
    c2vlanlist=$(cat $RCFILE2 | grep vlan | awk '{print substr($0, index($0, $4))}')

    echo $c1vlanlist | tr " " "\n" | sort -u > $controller1rcvlans
    echo $c2vlanlist | tr " " "\n" | sort -u > $controller2rcvlans

    missingrcvlansc1=$(comm -23 $vfilervlans $controller1vlans | tr '\n' ';')
    missingrcvlansc2=$(comm -23 $vfilervlans $controller2vlans | tr '\n' ';')
    extrarcvlansc1=$(comm -13 $vfilervlans $controller1vlans | tr '\n' ';')
    extrarcvlansc2=$(comm -13 $vfilervlans $controller2vlans | tr '\n' ';')

    #remove temporary files
    rm $vfilerrcvlans
    rm $controller1rcvlans
    rm $controller2rcvlans
} #End look at the vlans in use on the vFilers and compare to what exists in each controllers RC file

#Start look at the interface partners in the RC file
check_partner_syntax()
{
    #create variables
    controller1badpartner=""
    controller2badpartner=""
    controller1missingpartner=""
    controller2missingpartner=""

    #read through all the lines of the rc file to verify matching partner syntaxes
    while read line
    do
        #find interface configuration lines that are not alias lines
        if [[ $line =~ ^ifconfig.* && ! $line =~ .*alias.* ]]
        then
            #create variables
            partnerfound=0 #determine if the partner syntax was found
            x=0 #counter
            IFS=', ' read -a array <<< "$line" #convert the ifconfig line to an array

            #read through the line to find partner statements
            for ifarg in $line
            do
                x=$((x+1)) #count

                #check argument for partner syntax
                if [[ $ifarg == partner ]]
                then
                    partnerfound=1 #partner found
                    interface="${array[1]}" #get the primary interface name
                    partnerinterface="${array[$x]}" #get the partner interface name

                    #determine if the interface is a vif
                    if [[ $interface =~ ^vif.* ]]
                    then
                        #take out the number in the vif names since they do not match...
                        interface=$(echo "${array[1]}" | sed 's/vif[0-9]-/vif-/')
                        partnerinterface=$(echo "${array[$x]}" | sed 's/vif[0-9]-/vif-/')
                    fi #determine if the interface is a vif

                    #compare the interface names to verify that they match
                    if [[ $interface != $partnerinterface ]]
                    then
                        controller1badpartner="$controller1badpartner;${array[1]}"
                    fi #compare the interface names to verify that they match
                fi #check argument for partner syntax
            done #read through the line to find partner statements

            #If not partner syntax was found, notify
            if [ $partnerfound -eq 0 ]
            then
                controller1missingpartner="$controller1missingpartner;${array[1]}"
            fi #If not partner syntax was found, notify
        fi #find interface configuration lines that are not alias lines
    done < $RCFILE1 #read through all the lines of the rc file to verify matching partner syntaxes

    #read through all the lines of the rc file to verify matching partner syntaxes
    while read line
    do
        #find interface configuration lines that are not alias lines
        if [[ $line =~ ^ifconfig.* && ! $line =~ .*alias.* ]]
        then
            #create variables
            partnerfound=0 #determine if the partner syntax was found
            x=0 #counter
            IFS=', ' read -a array <<< "$line" #convert the ifconfig line to an array

            #read through the line to find partner statements
            for ifarg in $line
            do
                x=$((x+1)) #count

                #check argument for partner syntax
                if [[ $ifarg == partner ]]
                then
                    partnerfound=1 #partner found
                    interface="${array[1]}" #get the primary interface name
                    partnerinterface="${array[$x]}" #get the partner interface name

                    #determine if the interface is a vif
                    if [[ $interface =~ ^vif.* ]]
                    then
                        #take out the number in the vif names since they do not match...
                        interface=$(echo "${array[1]}" | sed 's/vif[0-9]-/vif-/')
                        partnerinterface=$(echo "${array[$x]}" | sed 's/vif[0-9]-/vif-/')
                    fi #determine if the interface is a vif

                    #compare the interface names to verify that they match
                    if [[ $interface != $partnerinterface ]]
                    then
                        controller2badpartner="$controller2badpartner;${array[1]}"
                    fi #compare the interface names to verify that they match
                fi #check argument for partner syntax
            done #read through the line to find partner statements

            #If not partner syntax was found, notify
            if [ $partnerfound -eq 0 ]
            then
                controller2missingpartner="$controller2missingpartner;${array[1]}"
            fi #If not partner syntax was found, notify
        fi #find interface configuration lines that are not alias lines
    done < $RCFILE2 #read through all the lines of the rc file to verify matching partner syntaxes

} #End look at the interface partners in the RC file

#Main Program
create_outputfile

#loop through controller list
for CONTROLLERNAMES in $(cat $CONTROLLERLIST)
do
    #split the contoller names
    GETCONTROLLER1=$(echo $CONTROLLERNAMES | awk '{split($0,a,","); print a[1]}')
    GETCONTROLLER2=$(echo $CONTROLLERNAMES | awk '{split($0,a,","); print a[2]}')

	#collect the input files
	#ssh root@$GETCONTROLLER1 'rdfile /etc/rc' > /tmp/"$GETCONTROLLER1"-rc
	#ssh root@$GETCONTROLLER1 'ipspace list' > /tmp/"$GETCONTROLLER1"-ipspaces
	#ssh root@$GETCONTROLLER1 'vfiler status -r' > /tmp/"$GETCONTROLLER1"-vfilers
	#ssh root@$GETCONTROLLER2 'rdfile /etc/rc' > /tmp/"$GETCONTROLLER2"-rc
	#ssh root@$GETCONTROLLER2 'ipspace list' > /tmp/"$GETCONTROLLER2"-ipspaces
	#ssh root@$GETCONTROLLER2 'vfiler status -r' > /tmp/"$GETCONTROLLER2"-vfilers

    #sanitize the input files for each controller
    grep -v "^#" $SCRIPTDIR/"$GETCONTROLLER1"-rc > /tmp/RCFILE1
    grep -v "^#" $SCRIPTDIR/"$GETCONTROLLER1"-ipspaces > /tmp/IPSPACESFILE1
    grep -v "^#" $SCRIPTDIR/"$GETCONTROLLER1"-vfilers > /tmp/VFILERSFILE1
    grep -v "^#" $SCRIPTDIR/"$GETCONTROLLER2"-rc > /tmp/RCFILE2
    grep -v "^#" $SCRIPTDIR/"$GETCONTROLLER2"-ipspaces > /tmp/IPSPACESFILE2
    grep -v "^#" $SCRIPTDIR/"$GETCONTROLLER2"-vfilers > /tmp/VFILERSFILE2

    #set the input files for each controller
    RCFILE1=/tmp/RCFILE1
    IPSPACESFILE1=/tmp/IPSPACESFILE1
    VFILERSFILE1=/tmp/VFILERSFILE1
    RCFILE2=/tmp/RCFILE2
    IPSPACESFILE2=/tmp/IPSPACESFILE2
    VFILERSFILE2=/tmp/VFILERSFILE2

    check_ipspaces

    check_ipspace_members

    check_interfaces

    check_vlans

    check_partner_syntax

    #create the output from all the commands
    echo "$GETCONTROLLER1,$missingipspacesc1,$extraipspacesc1,$missingipspacemembersc1full,$missinginterfacesc1,$extrainterfacesc1,$missingvlansc1,$extravlansc1,$missingrcvlansc1,$extrarcvlansc1,$controller1badpartner,$controller1missingpartner" >> $OUTPUTFILE
    echo "$GETCONTROLLER2,$missingipspacesc2,$extraipspacesc2,$missingipspacemembersc2full,$missinginterfacesc2,$extrainterfacesc2,$missingvlansc2,$extravlansc2,$missingrcvlansc2,$extrarcvlansc2,$controller2badpartner,$controller2missingpartner" >> $OUTPUTFILE

done #loop through controller list

exit 0