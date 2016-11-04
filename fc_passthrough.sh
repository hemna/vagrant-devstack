#!/bin/bash

# Script to show and select a virsh domain

TRIAL=0
VERBOSE=0

usage() {
cat << EOF
usage: $0 options

OPTIONS:
   -t      Trial run 
   -v      Verbose
EOF
}


while getopts “tv” OPTION
do
     case $OPTION in
         t)
             TRIAL=1
             ;;
         v)
             VERBOSE=1
             ;;
         ?)
             usage
             exit
             ;;
     esac
done


# get the menu function                                                         
SCRIPTDIR=$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")                       
source $SCRIPTDIR/lib/menu.sh

domains=$(virsh list --all | tail -n +3 | head -n +4 | xargs -i echo "{}" |
sort | cut -c7- | cut -c-31)

DOMAIN=$(menu 'Select VM to use:' $domains)
[[ -n $DOMAIN ]] || exit 1      # user canceled
#echo "Using VM '$DOMAIN'"

fcdevs=$(python $SCRIPTDIR/lib/fc_devices.py)
#echo "FCDEVS: '$fcdevs'"
FC=$(menu 'Select PCI device:' $fcdevs)
#echo "Using FC: '$FC'"

SCRIPT="python $SCRIPTDIR/lib/fc_passthrough.py "
if [[ "$FC" == "All" ]]; then
    SCRIPT_OPTS="--all "
else
    SCRIPT_OPTS="--device $FC "
fi

if [ $TRIAL -eq 1 ]; then
    SCRIPT_OPTS="$SCRIPT_OPTS --trial"
fi

if [ $VERBOSE -eq 1 ]; then
    SCRIPT_OPTS="$SCRIPT_OPTS --verbose"
fi

SCRIPT_OPTS="$SCRIPT_OPTS $DOMAIN"


cmd="$SCRIPT $SCRIPT_OPTS"
echo $cmd
$($cmd)
