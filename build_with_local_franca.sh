#!/bin/bash

# ==============================================================================
# Script Name: build_local_franca.sh
# Description: Modifies CommonAPI Core Target to use a local Franca build 
#              and triggers the Maven build.
# Usage: ./build_local_franca.sh <LOCAL_REPO_PATH> <FRANCA_VERSION>
# ==============================================================================

# --- 1. Validate Arguments ---
if [ "$#" -ne 2 ]; then
    echo "Error: Invalid number of arguments."
    echo "Usage: $0 <FULL_PATH_TO_REPO> <VERSION>"
    echo "Example: $0 /home/username/Desktop/cb865_franca-master/... 0.13.2.202512212242"
    exit 1
fi

LOCAL_REPO_PATH=$1
FRANCA_VERSION=$2
TARGET_FILE="org.genivi.commonapi.core.target/org.genivi.commonapi.core.target.target"
RELENG_DIR="org.genivi.commonapi.core.releng"

# --- 2. Check if Target File Exists ---
if [ ! -f "$TARGET_FILE" ]; then
    echo "Error: Target file not found at: $TARGET_FILE"
    echo "Please make sure you are running this script from the root of the CommonAPI Core repository."
    exit 1
fi

echo "--- Starting Configuration for Local Franca Build ---"
echo "Target File: $TARGET_FILE"
echo "Local Repo:  $LOCAL_REPO_PATH"
echo "Version:     $FRANCA_VERSION"

# Create a backup of the original file just in case
cp "$TARGET_FILE" "${TARGET_FILE}.bak"
echo "Backup created at ${TARGET_FILE}.bak"

# --- 3. Comment out the Remote Franca Location ---
# We use Perl (-0777) to read the whole file to handle multi-line matching.
# We look for the <location> block that contains the franca.github.io URL.
echo "Commenting out remote Franca repository..."

perl -0777 -i -pe 's|(<location[^>]*?>\s*<unit[^>]*?>\s*<unit[^>]*?>\s*<unit[^>]*?>\s*<repository location="http://franca.github.io/franca/update_site/releases"/>\s*</location>)||gs' "$TARGET_FILE"

# --- 4. Append the Local Franca Location ---
echo "Injecting local Franca configuration..."

# Construct the new XML block
# Note: We escape newlines for the Perl substitution below
NEW_BLOCK="
<location includeAllPlatforms=\"false\" includeConfigurePhase=\"false\" includeMode=\"planner\" includeSource=\"true\" type=\"InstallableUnit\">
    <unit id=\"org.franca.core.sdk.feature.group\" version=\"$FRANCA_VERSION\"/>
    <unit id=\"org.franca.providers.sdk.feature.group\" version=\"$FRANCA_VERSION\"/>
    <unit id=\"org.franca.ui.sdk.feature.group\" version=\"$FRANCA_VERSION\"/>
    <repository location=\"file:$LOCAL_REPO_PATH\"/>
</location>"

# Use Perl to insert the NEW_BLOCK just before the closing </locations> tag
# We pass the shell variable NEW_BLOCK to perl using env var to avoid quoting hell
export NEW_BLOCK
perl -0777 -i -pe 's|</locations>|$ENV{NEW_BLOCK}\n</locations>|' "$TARGET_FILE"

echo "Target file modification complete."

# --- 5. Run the Build ---
echo "--- Starting Maven Build ---"

if [ -d "$RELENG_DIR" ]; then
    cd "$RELENG_DIR" || exit
    
    echo "Directory changed to: $(pwd)"
    echo "Running mvn install..."
    
    JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 mvn install -U -Dtarget.id=org.genivi.commonapi.core.target
else
    echo "Error: Releng directory $RELENG_DIR not found!"
    exit 1
fi

echo "--- Script Finished ---"