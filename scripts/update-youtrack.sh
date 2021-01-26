#!/usr/bin/env bash
set -euo pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/.."

REL=$(curl --silent 'https://data.services.jetbrains.com/products/releases?code=YTD&latest=true&type=release&build=' | jq '.YTD[0]')

VERSION=$(echo "$REL" | jq -r '"\(.version).\(.build)"')
URL=$(echo "$REL" | jq -r '.downloads.javaEE.link')
HASH_URL=$(echo "$REL" | jq -r '.downloads.javaEE.checksumLink')
NOTES_LINK=$(echo "$REL" | jq -r '.notesLink')

HASH=$(curl "$HASH_URL" | cut -d' ' -f1)

CUR_URL=$(jq -r .url $ROOT/overlay/youtrack_rev.json)
CUR_VERSION=$(jq -r .version $ROOT/overlay/youtrack_rev.json)

if [[ "$URL" == "$CUR_URL" ]]; then
    echo "no update needed"
    exit 0
fi

git fetch origin
git checkout -B "upd-youtrack-$VERSION" origin/master
echo "updating from $CUR_URL to $URL"
echo "RELEASE NOTES: $NOTES_LINK"
echo "$(jq ".version = \"$VERSION\" | .url = \"$URL\" | .sha256 = \"$HASH\"" < $ROOT/overlay/youtrack_rev.json)" > $ROOT/overlay/youtrack_rev.json
git add ./overlay/youtrack_rev.json
git commit -m "youtrack: $CUR_VERSION -> $VERSION

automatically generated :)
[release notes]($NOTES_LINK)"
git push origin HEAD
hub pull-request --no-edit -r serokell/operations -o
git checkout -
