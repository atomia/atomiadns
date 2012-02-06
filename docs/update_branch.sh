#!/bin/sh

if [ -z "$1" ] || [ ! -d "$1/.git" ]; then
	echo "usage: $0 git-repo-clone branch-to-update-should-contain-only-docs"
	exit 1
fi

repo="$1"
branch="$2"

curdir=`pwd`

cd "$repo"
git checkout "$branch"
git pull

cd "$curdir"
./generate_html.sh "$repo"

cd "$repo"
git add -A
git commit -m "Auto-sync documentation branch with manual.xml"
git push origin HEAD:refs/heads/"$branch"
