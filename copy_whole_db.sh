if [ "x$6" == "x" ]; then
  echo "Usage: ./copy_whole_db.sh sourceuser sourcepass sourcedb destuser destpass destdb"
  exit
fi

if [ "x$1" == "x--check" ]; then
   check=true
   shift
fi

sourceuser=$1
sourcepass=$2
sourcedb=$3
destuser=$4
destpass=$5
destdb=$6


if [ "$check" == "true" ]; then
  collections=`echo "show collections" | mongo $sourcedb -u $sourceuser -p $sourcepass --quiet | grep -v "^system\."`
  echo mongo $sourcedb -u $sourceuser -p $sourcepass --quiet 
  for i in $collections; do
    echo "print(db.$i.count(), \"\t$i\")"
  done | mongo $sourcedb -u $sourceuser -p $sourcepass --quiet > tmp_a
  echo mongo $destdb -u $destuser -p $destpass --quiet
  for i in $collections; do
    echo "print(db.$i.count(), \"\t$i\")"
  done | mongo $destdb -u $destuser -p $destpass --quiet > tmp_b
  diff tmp_a tmp_b

else
  mkdir -p log
  echo "mongo $destdb -u $destuser -p $destpass"
  read
  echo "db.dropDatabase()" | mongo $destdb -u $destuser -p $destpass
  echo "show collections" | mongo $sourcedb -u $sourceuser -p $sourcepass --quiet | grep -v "^system\." | while read collection; do
    ./copy_collection.py \
      --source $sourceuser:$sourcepass@$sourcedb/$collection \
      --dest   $destuser:$destpass@$destdb/$collection \
       > log/$collection.log 2>&1 &
  done
  sleep 5
  grep Traceback log/*
fi
