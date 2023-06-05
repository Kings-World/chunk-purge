#!/bin/sh

# https://dashflo.net/docs/api/pterodactyl/v1/
backup=$(
  curl -s "$API_URL/servers/$SERVER_ID/backups" \
  -H "Authorization: Bearer $API_KEY"\
  -H "Content-Type: application/json" \
  -H "Accept: Application/vnd.pterodactyl.v1+json" \
  | jq ".data | last"
)

backup_uuid=$(echo $backup | jq -r ".attributes.uuid")
backup_name=$(echo $backup | jq -r ".attributes.name")
backup_created_at=$(echo $backup | jq -r ".attributes.created_at")

echo "Found backup: $backup_name ($backup_uuid)"

if [ -f "/data/$backup_uuid.tar.gz" ]; then
  # https://linuxize.com/post/bash-check-if-file-exists/
  echo "An existing backup was found, removing it..."
  rm /data/$backup_uuid.tar.gz
  rm -rf /data/$backup_uuid
fi

if [ ! -d "/data/$backup_uuid" ]; then
  echo "Creating the /data/$backup_uuid directory"
  mkdir /data/$backup_uuid
fi

cd /data/$backup_uuid
cp /backups/$backup_uuid.tar.gz /data
tar -xzf /data/$backup_uuid.tar.gz
cd /app

world="/data/$backup_uuid/world"

# ----------------------------------------------

echo "Purging the Overworld chunks"

java -jar mcaselector-2.1.jar \
  --mode delete \
  --world $world \
  --query "InhabitedTime < \"2 minutes\""

echo "Purging the Nether chunks"

java -jar mcaselector-2.1.jar \
  --mode delete \
  --world $world/DIM-1 \
  --query "InhabitedTime < \"2 minutes\""

echo "Purging the End chunks"

java -jar mcaselector-2.1.jar \
  --mode delete \
  --world $world/DIM1 \
  --query "InhabitedTime < \"2 minutes\""

# ----------------------------------------------

echo "Overriding level.dat"
# https://minecraft.fandom.com/wiki/Java_Edition_level_format#level.dat_format

echo "Allowing cheats to be used"
python3 ./mc-nbt-edit.py $world/level.dat Data.allowCommands int 1

echo "Setting level name to $SERVER_NAME"
python3 ./mc-nbt-edit.py $world/level.dat Data.LevelName string "$SERVER_NAME"

echo "Copying the Kings World icon"
cp /data/icon.png $world/

echo "Removing audio player data"
rm -rf $world/audio_player_data

# ----------------------------------------------

echo "Creating the world zip"

name="$SERVER_NAME $(date "+%Y-%m-%d").zip"
cd $world

if [ -f "../../$name" ]; then
  # https://linuxize.com/post/bash-check-if-file-exists/
  echo "An existing zip file was found, removing it..."
  rm "../../$name"
fi

zip -rq "$name" *
mv "$name" ../../

# ----------------------------------------------

echo "Deleting temporary files"
rm -rf /data/$backup_uuid
rm -rf /data/$backup_uuid.tar.gz

echo "Purge complete! \"$name\" ($(ls -lha /data | grep total)) has been created."

# ----------------------------------------------

echo "Uploading to R2"

escaped_name=$(echo $name | sed "s/ /%20/g")
backup_url="$DOMAIN$SUBPATH$escaped_name"

cd /data
aws s3 cp "$name" s3://$BUCKET$SUBPATH --endpoint-url $ENDPOINT_URL

# ${SUBPATH:-/}

# ----------------------------------------------

echo "Sending to Discord"

# current date markdown:
# <t:$(date +"%s"):D>

# backup date markdown:
# <t:$(date -d $backup_created_at +"%s"):D>

epoch=$(date -d $backup_created_at +"%s")
content="Backup for <t:$epoch:D>\n$backup_url"

curl -X POST "$DISCORD_WEBHOOK?wait=false" \
  -H "Content-Type: application/json" \
  -d "{\"content\":\"$content\"}"

# ----------------------------------------------

echo "Removing local file"

# rm "/data/$name"