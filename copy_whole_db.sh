if [ "x$6" == "x" ]; then
  echo "Usage: ./copy_whole_db.sh sourceuser sourcepass sourcedb destuser destpass destdb"
  exit
fi

sourceuser=$1
sourcepass=$2
sourcedb=$3
destuser=$4
destpass=$5
destdb=$6

mkdir -p log
echo "show collections" | mongo $sourcedb -u $sourceuser -p $sourcepass --quiet | while read collection; do
  echo "db.$collection.drop();" | mongo $destdb -u $destuser -p $destpass --quiet
  ./copy_collection.py \
    --source $sourceuser:$sourcepass@$sourcedb/$collection \
    --dest   $destuser:$destpass@$destdb/$collection \
    --restart > log/$collection.log 2>&1 &
done
sleep 5
grep Traceback log/*
