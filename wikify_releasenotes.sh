#!/bin/sh

program="Atomia DNS"
email="jimmy@atomia.com"

# Example entry:
#
#atomiadns-masterserver (0.9.5) hardy; urgency=low
#
#  * Fix .NET compatibility issues in RestoreZone, GetLabels and GetChangedZones
#  * Improve argument parsing in atomiadnsclient
#
# -- Jimmy Bergman <jimmy@sigint.se>  Tue, 19 May 2009 08:27:45 +0200

latest_version="$(gawk '/urgency=/ { print gensub(/^.*\((.*)\).*$/, "\\1", ""); nextfile }' server/debian/changelog)"

gawk -vprogram="$program" '
	BEGIN {
		latest_version = 1 
		print "{toc}\n"
	}

	/urgency=/ {
		version = gensub(/^.*\((.*)\).*$/, "\\1", "")

		if (latest_version) {
			print "h4. Latest version, " program " " version
			level = "h5."
		} else {
			print "h5. " program " " version
			level = "h6."
		}

		do {
			getline
		} while (match($0, /^[ 	\t]*$/))

		changes = ""
		do {
			if(!match($0, /^[ \t]*$/)) {
				changes = changes gensub(/^[ \t]*(.*)$/, "\\1", "")
			}
			getline
		} while (!match($0, /^[ \t]*$/))

		getline

		releasedate = gensub(/^.*>[^A-Za-z]*(.*)$/, "\\1", "")

		print ""
		print level " Changes"
		print changes
		print ""
		print level " Released at"
		print "This version was released at " releasedate
		print ""

		if (latest_version) {
			latest_version = 0
			print "h4. Previous versions\n"
		}
	}
	
' server/debian/changelog | mail -s "$program release notes for $latest_version" "$email"
