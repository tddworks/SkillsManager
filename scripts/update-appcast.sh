#!/bin/bash
# Update appcast.xml with a new release entry
# Usage: ./scripts/update-appcast.sh <version> <build_number> <download_url> <signature> <file_size> [release_notes] [channel]
# channel: Optional. Set to "beta" for pre-release versions to enable beta channel filtering.
#
# This script maintains BOTH the latest stable AND latest beta versions in the appcast.
# This ensures:
# - Stable users always see the latest stable version (even when betas exist)
# - Beta users see both and get the newest version (beta or stable)

set -e

VERSION="$1"
BUILD_NUMBER="$2"
DOWNLOAD_URL="$3"
ED_SIGNATURE="$4"
FILE_SIZE="$5"
RELEASE_NOTES="${6:-Bug fixes and improvements.}"
CHANNEL="${7:-}"  # Optional: "beta" for pre-release versions
PUB_DATE=$(date -R)

mkdir -p docs

APPCAST_FILE="docs/appcast.xml"

# Filter out Technical section (developer-focused, not for end users)
# Removes everything from "### Technical" to the next section or end
# Also converts **bold** to plain text for cleaner user display
filter_for_users() {
    awk '
        /^### Technical/ { skip=1; next }
        /^### / { skip=0 }
        skip == 0 { print }
    ' | sed 's/\*\*\([^*]*\)\*\*/\1/g'
}

# Convert markdown to clean HTML for Sparkle
# Process line by line for proper list handling
convert_to_html() {
    local in_list=false
    local result=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines
        if [[ -z "$line" ]]; then
            if $in_list; then
                result+="</ul>"
                in_list=false
            fi
            continue
        fi

        # Handle ### Heading
        if [[ "$line" =~ ^###[[:space:]]+(.*) ]]; then
            if $in_list; then
                result+="</ul>"
                in_list=false
            fi
            result+="<h3>${BASH_REMATCH[1]}</h3>"
        # Handle - list item
        elif [[ "$line" =~ ^-[[:space:]]+(.*) ]]; then
            if ! $in_list; then
                result+="<ul>"
                in_list=true
            fi
            # Convert backticks to <code>
            local item="${BASH_REMATCH[1]}"
            item=$(echo "$item" | sed 's/`\([^`]*\)`/<code>\1<\/code>/g')
            result+="<li>$item</li>"
        else
            if $in_list; then
                result+="</ul>"
                in_list=false
            fi
            result+="<p>$line</p>"
        fi
    done

    if $in_list; then
        result+="</ul>"
    fi

    echo "$result"
}

# Filter out Technical section, then convert to HTML
HTML_NOTES=$(echo "$RELEASE_NOTES" | filter_for_users | convert_to_html)

# Human-readable date for display
DISPLAY_DATE=$(date "+%B %d, %Y")

# Build channel tag if specified
CHANNEL_TAG=""
IS_BETA=false
if [[ -n "$CHANNEL" ]]; then
    CHANNEL_TAG="            <sparkle:channel>${CHANNEL}</sparkle:channel>"
    IS_BETA=true
    echo "This is a beta release, adding channel: $CHANNEL"
else
    echo "This is a stable release (no channel tag)"
fi

# Create the new item XML
NEW_ITEM=$(cat << EOF
        <item>
            <title>${VERSION}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <sparkle:version>${BUILD_NUMBER}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
${CHANNEL_TAG}
            <description><![CDATA[<h2>Skills Manager ${VERSION}</h2>
<p><em>Released ${DISPLAY_DATE}</em></p>
${HTML_NOTES}
<p><a href="https://github.com/tddworks/SkillsManager/releases/tag/v${VERSION}">View full release notes</a></p>
]]></description>
            <enclosure url="${DOWNLOAD_URL}" length="${FILE_SIZE}" type="application/octet-stream" sparkle:edSignature="${ED_SIGNATURE}"/>
        </item>
EOF
)

# Extract existing items from appcast if it exists
EXISTING_STABLE_ITEM=""
EXISTING_BETA_ITEM=""

if [[ -f "$APPCAST_FILE" ]]; then
    echo "Found existing appcast, extracting items..."

    # Extract all items using awk (each item block is between <item> and </item>)
    ITEMS=$(awk '/<item>/,/<\/item>/' "$APPCAST_FILE")

    # Extract the first stable item (item without sparkle:channel)
    EXISTING_STABLE_ITEM=$(echo "$ITEMS" | awk '
        /<item>/ { item=""; in_item=1 }
        in_item { item = item $0 "\n" }
        /<\/item>/ {
            in_item=0
            if (item !~ /<sparkle:channel>/) {
                print item
                exit  # Only keep the first stable item
            }
        }
    ')

    # Extract the first beta item (item with sparkle:channel)
    EXISTING_BETA_ITEM=$(echo "$ITEMS" | awk '
        /<item>/ { item=""; in_item=1 }
        in_item { item = item $0 "\n" }
        /<\/item>/ {
            in_item=0
            if (item ~ /<sparkle:channel>/) {
                print item
                exit  # Only keep the first beta item
            }
        }
    ')

    # Trim trailing empty lines from extracted items
    if [[ -n "$EXISTING_STABLE_ITEM" ]]; then
        EXISTING_STABLE_ITEM=$(printf '%s' "$EXISTING_STABLE_ITEM" | sed '/^[[:space:]]*$/d')
        echo "Found existing stable item"
    fi

    if [[ -n "$EXISTING_BETA_ITEM" ]]; then
        EXISTING_BETA_ITEM=$(printf '%s' "$EXISTING_BETA_ITEM" | sed '/^[[:space:]]*$/d')
        echo "Found existing beta item"
    fi
fi

# Determine which items to include in the final appcast
# Rule: Always keep both latest stable AND latest beta
# - If releasing beta: keep existing stable, replace beta with new
# - If releasing stable: keep existing beta, replace stable with new

ITEMS_TO_WRITE=""

if $IS_BETA; then
    # Releasing a beta version
    # New item replaces any existing beta
    # Keep existing stable if present
    ITEMS_TO_WRITE="$NEW_ITEM"
    if [[ -n "$EXISTING_STABLE_ITEM" ]]; then
        ITEMS_TO_WRITE=$(printf '%s\n%s' "$NEW_ITEM" "$EXISTING_STABLE_ITEM")
        echo "Keeping existing stable version alongside new beta"
    fi
else
    # Releasing a stable version
    # New item replaces any existing stable
    # Keep existing beta if present
    ITEMS_TO_WRITE="$NEW_ITEM"
    if [[ -n "$EXISTING_BETA_ITEM" ]]; then
        ITEMS_TO_WRITE=$(printf '%s\n%s' "$NEW_ITEM" "$EXISTING_BETA_ITEM")
        echo "Keeping existing beta version alongside new stable"
    fi
fi

# Write the final appcast
cat > "$APPCAST_FILE" << EOF
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>Skills Manager</title>
$ITEMS_TO_WRITE
    </channel>
</rss>
EOF

echo ""
echo "Generated appcast.xml with $(echo "$ITEMS_TO_WRITE" | grep -c '<item>') item(s):"
cat "$APPCAST_FILE"
