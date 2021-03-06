#!/bin/sh

usage() {
  echo "Usage: $0 [ --filename <filename.sql>  || --path <path_of_file>]" 1>&2;
  exit 1;
}

# Options
ARGS=$(getopt -o 'f:p:' --long 'filename:,path:' -- "$@") || exit 1
eval "set -- $ARGS"

while true; do
  case "$1" in
    (-f|--filename)
      export FILENAME="$2"; shift 2;;
    (-p|--path)
      export FILEPATH="$2"; shift 2;;
    (--) shift; break;;
    (*) usage;;
  esac
done
if [ -z "$FILENAME" ] && [ -z "$FILEPATH" ]; then
    usage
fi
# If both are set, we should not process
if [ ! -z "$FILENAME" ] && [ ! -z "$FILEPATH" ]; then
    usage
fi

# Change working directory to the drupal code
cd /app

# Database drop
echo "Dropping database"
drush sql-drop -y

# Database restore
if [[ ! -z "$FILEPATH" ]]; then
    echo "Restoring database from $FILEPATH"
    `drush sql-connect` < $FILEPATH
else
    echo "Restoring database from /drupal-data/$FILENAME"
    `drush sql-connect` < /drupal-data/$FILENAME
fi

# If we restore between namespaces (in order to clone), the source database will have the wrong OIDC credentials.
# After restoring, for safety, enforce the OIDC credentials of the destination.
drush config:set -y openid_connect.settings.generic settings.client_id "$clientID"
drush config:set -y openid_connect.settings.generic settings.client_secret "$clientSecret"
