#!/bin/bash

# Function to fix manifest file
fix_manifest() {
    local manifest_file="$1"
    if [ -f "$manifest_file" ]; then
        echo "Processing $manifest_file"
        
        # Create a backup
        cp "$manifest_file" "${manifest_file}.bak"
        
        # Remove package attribute using a more specific sed pattern
        sed -i '' 's/manifest[[:space:]]*package="[^"]*"/manifest/g' "$manifest_file"
        
        echo "Fixed manifest: $manifest_file"
        
        # Verify the change
        echo "Current manifest content:"
        head -n 2 "$manifest_file"
    else
        echo "Manifest file not found: $manifest_file"
    fi
}

# Fix manifests for all plugins
fix_manifest "$HOME/.pub-cache/hosted/pub.dev/smart_auth-1.1.1/android/src/main/AndroidManifest.xml"
fix_manifest "$HOME/.pub-cache/hosted/pub.dev/sqflite_android-2.4.1/android/src/main/AndroidManifest.xml"
fix_manifest "$HOME/.pub-cache/hosted/pub.dev/url_launcher_android-6.3.14/android/src/main/AndroidManifest.xml"
fix_manifest "$HOME/.pub-cache/hosted/pub.dev/wakelock_plus-1.2.10/android/src/main/AndroidManifest.xml" 