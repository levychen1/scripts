#!/bin/bash
runcli()
{
	/opt/radware/dfc/CURRENT/scripts/cli.sh $@
}

createpoandip() #Creating a PO and inserting networks
{
	PO=$1
	NET=$2
	BACKUP_NET=$2
	CLI="0"
	OCTET4=0
	OCTET3=0
	OCTET2=0
	OCTET1=1
	EXIT_CODE=0
	while [ "$PO" -gt "0" ]
	do
		CLI="dfc-protected-object:add -name PO$PO -workflow OutOfPath -bandwidth 123456 -admin-status DISABLED"
		runcli $CLI > /dev/null 2>&1
		if [ $? != 0 ]; then
			return 1
		fi
		while [ "$OCTET1" -lt "256" -a "$NET" -gt "0" ]
		do
			OCTET1=$((OCTET1+1))
			while [ "$OCTET2" -lt "256" -a "$NET" -gt "0" ]
			do
				OCTET2=$((OCTET2+1))
				while [ "$OCTET3" -lt "256" -a "$NET" -gt "0" ]
				do
					OCTET3=$((OCTET3+1))
					while [ "$OCTET4" -lt "256" -a "$NET" -gt  "0" ]
					do
						OCTET4=$((OCTET4+1))
						CLI="dfc-protected-network:add -network $OCTET1.$OCTET2.$OCTET3.$OCTET4 -network-group PE -protected-object PO$PO"
						runcli $CLI > /dev/null 2>&1
						EXIT_CODE=$?
						if [ "$EXIT_CODE"  == "0" ]; then
							NET=$((NET-1))
							echo "Network $OCTET1.$OCTET2.$OCTET3.$OCTET4 has been added to PO$PO.."
						else
							return 1
						fi
					done
					OCTET4=0
				done
				OCTET3=0
			done
			OCTET2=0
		done
		echo "PO$PO has been created.."
		OCTET1=1
		PO=$((PO-1))
		NET=$BACKUP_NET
	done
	return 0
}

deletepo() #This function deletes POs by a given range
{
	FIRSTPO=$1
	SECONDPO=$2
	CLI="0"
	EXIT_CODE="0"
	if [ $FIRSTPO -gt $SECONDPO ] ; then
		TEMP=$SECONDPO
		SECONDPO=$FIRSTPO
		FIRSTPO=$TEMP
	fi
	POCOUNT=$SECONDPO
	while [ "$POCOUNT" -ge "$FIRSTPO" ] && [ "$POCOUNT" -le "$SECONDPO" ] && [ "$EXIT_CODE" == "0" ]
	do
		##Verify PO can be deleted
 		verifypoexists $POCOUNT
		EXIT_CODE=$?
		if [ "$EXIT_CODE" == "0" ]; then
			echo "PO$POCOUNT does not exist - Skipping.."
			POCOUNT=$((POCOUNT-1))
			continue
		fi
		runcli "dfc-protected-object:edit -name PO$POCOUNT -admin-status DISABLED" > /dev/null 2>&1
		verifynoprotection $POCOUNT
		EXIT_CODE=$?
		if [ "$EXIT_CODE" -gt "0" ]; then
			while [ "$EXIT_CODE" -gt "0" ] #In case protections are not finished yet. Keep waiting for policy export to be done
			do
				verifynoprotection $POCOUNT
				EXIT_CODE=$? 
			done
			runcli "dfc-protected-object:delete -name PO$POCOUNT" > /dev/null 2>&1
			EXIT_CODE=$?
			if [ "$EXIT_CODE" != "0" ]; then
				return 1
			fi
		##Done verifying PO can be deleted and deletion
		else
			runcli "dfc-protected-object:delete -name PO$POCOUNT" > /dev/null 2>&1 #Any other case which PO is DISABLED, delete it
		fi
		echo "PO$POCOUNT has been deleted."
		POCOUNT=$((POCOUNT-1))
	done
	return 0
}

verifynoprotection() #This function verifies there are no protections regarding the given PO
{
	PO=$1
	OUTPUT=$(runcli "dfc-monitor:protection-list -protected-object PO$PO" | grep -w "PO$PO" | wc -l)
	return $OUTPUT
}

verifypoexists() #This function verifies that the given PO had not been deleted, and it really is found in the DB
{
	PO=$1
	OUTPUT=$(runcli "dfc-protected-object:list" | grep -w "PO$PO" | wc -l)
	return $OUTPUT
}

createpolanding() #Landing menu for PO creation
{
	PO="0"
	NET="0"
	EXIT_CODE="0"
	echo -n "How many POs do you want me to create? (\"Exit\" to quit): " ; read PO
	if [ "$PO" -gt "0" -a "$PO" != "Exit" ] > /dev/null 2>&1 ; then 
		echo -n "How many networks do you want in each one of them (\"Exit\" to quit): " ; read NET
		if [ "$NET" -gt "0" -a "$NET" != "Exit" ] > /dev/null 2>&1 ; then
			echo "Gotcha.. Now go take a piss or something.."
			createpoandip $PO $NET
			if [ $? == 0 ]; then
				echo "All done my man check your DF/Vision for new POs"
				return 0
			fi
		elif [ "$NET" == "Exit" ] > /dev/null 2>&1 ; then
			echo "Bye bye dude"
			return 2
		else
			echo "I am sorry it seems that the entered values are invalid, see you again soon."
			return 1
		fi
	elif [ "$PO" == "Exit" ] > /dev/null 2>&1 ; then
		echo "Bye Bye dude"
		return 2 
	else 
		echo "I am sorry it seems that the entered values are invalid, see you again soon."
		return 1
	fi
}

deletepolanding() { ##Landing menu for PO deletion 
	FIRSTPO="0"
	SECONDPO="0"
	echo "Please be advised, deletion process only deletes a range of POs-"
	echo "which means if you want to delete only one of the POs mention the same number twice"
	echo -n "So.. Where should I start deleting?: PO" ; read FIRSTPO
	if [ "$FIRSTPO" -gt "0" -a "$FIRSTPO" != "Exit" ] > /dev/null 2>&1 ; then
		echo -n "Where should I stop deleting?: PO" ; read SECONDPO
		if [ "$SECONDPO" -ge "0" -a "$SECONDPO" != "Exit" ] > /dev/null 2>&1 ; then
			echo "Gotcha.. if you deleted a big amont of POs it may take some time.."
			deletepo $FIRSTPO $SECONDPO
			if [ $? == 0 ]; then
				echo "All done my man check your DF/Vision"
				return 0
			fi
		elif [ "$SECONDPO" == "Exit" ] > /dev/null 2>&1 ; then
			echo "Going to the main menu"
			return 2
		else
			echo "I am sorry it seems that the entered values are invalid, see you again soon."
			return 1
		fi
	elif [ "$FIRSTPO" == "Exit" ] > /dev/null 2>&1 ; then
		echo "Going to the main menu"
		return 2
	else
		echo "I am sorry, it seems that the entered values are invalid, see you again soon."
		return 1
	fi
}


##Main Menu

echo "Hi dear friend, How may I help you today?"
echo "Please select: "
options=("Create POs" "Delete POs" "Exit")
select opt in "${options[@]}"
do
	case $opt in
		"Create POs")
			createpolanding
			;;
		"Delete POs")
			deletepolanding
			;;
		"Exit")
			echo "Bye bye dude, it's been a pleasure"
			break
			;;
		*)
			echo "Invalid option, please try again.."
			;;
	esac
done
