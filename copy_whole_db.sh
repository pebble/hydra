#!/bin/bash

if [ "x$6" == "x" ]; then
  echo "Usage: ./copy_whole_db.sh SOURCE_USER SOURCE_PASS SOURCE_DB DEST_USER DEST_PASS DEST_DB"
  exit
fi

SOURCE_USER=$1
SOURCE_PASS=$2
SOURCE_DB=$3
DEST_USER=$4
DEST_PASS=$5
DEST_DB=$6

COLLECTIONS=$(echo "show collections" \
    | mongo $SOURCE_DB -u $SOURCE_USER -p $SOURCE_PASS --quiet \
    | grep -v "^system\." )

SOURCE_COUNTS=$( column -t <( for COLLECTION in ${COLLECTIONS}; do
    echo "print(db.${COLLECTION}.count(), \"\t${COLLECTION}\")" 
done | mongo $SOURCE_DB -u $SOURCE_USER -p $SOURCE_PASS --quiet ))

DEST_COUNTS=$( column -t <( for COLLECTION in ${COLLECTIONS}; do
    echo "print(db.${COLLECTION}.count(), \"\t${COLLECTION}\")" 
done | mongo $DEST_DB -u $DEST_USER -p $DEST_PASS --quiet ))

# Output table comparing SOURCE and DESTINATION collection counts
printf "\nSOURCE: $SOURCE_DB"
printf "\n\nDESTINATION: $DEST_DB\n\n"
printf '%-37s | %-38s\n' "--- SOURCE ---" "--- DESTINATION ---"
diff -y --width=80 \
    <(printf %s "$SOURCE_COUNTS") \
    <(printf %s "$DEST_COUNTS")

# Confirm with user before proceeding
printf "\n\n"
read -p "Sync SOURCE to DESTINATION (y/n)? " choice
case "$choice" in 
  n|N ) echo "Aborting sync."; exit;;
  y|Y ) echo "Starting sync...";;
  * ) echo "invalid";;
esac

# Start sync/tail processes for each collection
PIDS=()
for COLLECTION in $COLLECTIONS; do
    ./copy_collection.py \
      --source $SOURCE_USER:$SOURCE_PASS@$SOURCE_DB/$COLLECTION \
      --dest   $DEST_USER:$DEST_PASS@$DEST_DB/$COLLECTION
    PIDS=("${PIDS[@]}" "$!")
done

# Kill all sync processes and exit on <CTRL+C>
trap ctrl_c INT
function ctrl_c() {
    echo "Caught <Ctrl-C>. Exiting..."
    for PID in ${PIDS[@]}; do
        kill $PID
    done
    exit
}

# Sleep Forever
while true; do sleep 1; done
