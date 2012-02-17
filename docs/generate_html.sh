#!/bin/sh

if [ -z "$1" ] || [ ! -d "$1" ]; then
	echo "usage: $0 output_dir"
	exit 1
fi

xmlto xhtml --skip-validation -m config.xsl -o "$1" manual.xml
./docbook5topdf manual.xml "$1"/manual.pdf
cp -a *.html images resources "$1"
