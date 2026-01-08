#!/bin/bash
# Extract release notes for a specific version from CHANGELOG.md
# Usage: ./scripts/extract-changelog.sh <version>
# Example: ./scripts/extract-changelog.sh 1.0.0
#
# Output: The markdown content for that version, suitable for GitHub Release or appcast.xml

set -e

VERSION="$1"
CHANGELOG_FILE="${2:-CHANGELOG.md}"

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version> [changelog_file]" >&2
    echo "Example: $0 1.0.0" >&2
    exit 1
fi

if [ ! -f "$CHANGELOG_FILE" ]; then
    echo "Error: $CHANGELOG_FILE not found" >&2
    exit 1
fi

# Remove 'v' prefix if present
VERSION="${VERSION#v}"

# Extract section between [VERSION] header and next version header (or EOF)
# Pattern: Match from "## [VERSION]" to the next "## [" or end of file
awk -v version="$VERSION" '
    BEGIN { found=0; printing=0 }

    # Match the target version header
    /^## \[/ {
        if (printing) {
            # We hit the next version, stop printing
            exit
        }
        # Check if this is our target version
        if (index($0, "[" version "]") > 0) {
            found=1
            printing=1
            next  # Skip the header line itself
        }
    }

    # Print lines when we are in the right section
    printing { print }

    END {
        if (!found) {
            print "Error: Version " version " not found in changelog" > "/dev/stderr"
            exit 1
        }
    }
' "$CHANGELOG_FILE" | sed '/^$/N;/^\n$/d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
# The sed commands: remove multiple blank lines, and trim trailing blank lines
