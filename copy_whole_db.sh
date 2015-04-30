#!/bin/bash

if [ "x$2" == "x" ]; then
  echo "Usage: ./copy_whole_db.sh SOURCE_URI DEST_URI"
  exit
fi

SOURCE_URI=$1
DEST_URI=$2
MONGO_PATH="/usr/local/bin/bin/mongo"

mongo_uri_to_cli() {
    proto="$(echo $1 | grep :// | sed -e's,^\(.*://\).*,\1,g')"
    url="$(echo ${1/$proto/})"
    userpass="$(echo $url | grep @ | cut -d@ -f1)"
    user=$(echo $userpass | grep : | cut -d: -f1)
    pass=$(echo $userpass | grep : | cut -d: -f2)
    hostargs="$(echo ${url/$userpass@/})"
    host=$(echo $hostargs | grep : | cut -d? -f1)
    auth_opts=""
    if [[ $hostargs == *"authSource"* ]]; then
        auth_source=$(echo $hostargs | sed 's/.*authSource=\([a-zA-Z_-]\+\)/\1/g')
        auth_opts=" --authenticationDatabase $auth_source"
    fi
    $MONGO_PATH $host -u $user -p $pass $auth_opts ${@:2}
}

mongo_uri_add_collection(){
    uri=$1
    collection=$2
    host=$(echo $uri | grep : | cut -d? -f1)
    printf ${host}.${collection}
    if [[ $uri == *"?"* ]]; then
        args=$(echo $uri | grep : | cut -d? -f2)
        printf ?$args
    fi
}

COLLECTIONS=$(echo "show collections" \
    | mongo_uri_to_cli $SOURCE_URI --quiet \
    | grep -v "^system\." )


# Output table comparing SOURCE and DESTINATION collection counts
printf "\nSOURCE: $( echo $SOURCE_URI | awk -F/ '{print $3}' | cut -d@ -f2 |
cut -d: -f1 )\n"
printf "\nDESTINATION: $( echo $DEST_URI | awk -F/ '{print $3}' | cut -d@ -f2 |
cut -d: -f1 )\n\n"

SOURCE_COUNTS=$( column -t <( for COLLECTION in ${COLLECTIONS}; do
    echo "print(db.${COLLECTION}.count(), \"\t${COLLECTION}\")" 
done | mongo_uri_to_cli $SOURCE_URI --quiet ))

DEST_COUNTS=$( column -t <( for COLLECTION in ${COLLECTIONS}; do
    echo "print(db.${COLLECTION}.count(), \"\t${COLLECTION}\")" 
done | mongo_uri_to_cli $DEST_URI --quiet ))

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
for COLLECTION in $COLLECTIONS; do
    python2.7 copy_collection.py \
        --source $(mongo_uri_add_collection ${SOURCE_URI} ${COLLECTION}) \
        --dest $(mongo_uri_add_collection ${DEST_URI} ${COLLECTION}) &
done

# Kill all sync processes and exit on <CTRL+C>
trap ctrl_c INT
function ctrl_c() {
    echo "Caught <Ctrl-C>. Exiting..."
    kill $(jobs -pr)
    exit
}

# Sleep Forever
while true; do sleep 1; done
