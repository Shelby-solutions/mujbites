#!/bin/bash

# Function to fix manifest file
fix_manifest() {
    local manifest_file="$1"
    if [ -f "$manifest_file" ]; then
        # Create a backup
        cp "$manifest_file" "${manifest_file}.bak"
        
        # Remove package attribute using sed
        sed -i '' 's/package="[^"]*"//g' "$manifest_file"
        
        echo "Fixed manifest: $manifest_file"
    else
        echo "Manifest file not found: $manifest_file"
    fi
}

# Fix manifests for all plugins
fix_manifest "$HOME/.pub-cache/hosted/pub.dev/audioplayers_android-4.0.3/android/src/main/AndroidManifest.xml"
fix_manifest "$HOME/.pub-cache/hosted/pub.dev/device_info_plus-9.1.2/android/src/main/AndroidManifest.xml"
fix_manifest "$HOME/.pub-cache/hosted/pub.dev/connectivity_plus-5.0.2/android/src/main/AndroidManifest.xml"
fix_manifest "$HOME/.pub-cache/hosted/pub.dev/firebase_auth-4.20.0/android/src/main/AndroidManifest.xml"
fix_manifest "$HOME/.pub-cache/hosted/pub.dev/firebase_core-2.32.0/android/src/main/AndroidManifest.xml" 