#!/bin/bash

# Function to fix AndroidManifest.xml
fix_manifest() {
    local plugin_dir="$1"
    local manifest_file="$HOME/.pub-cache/hosted/pub.dev/$plugin_dir/android/src/main/AndroidManifest.xml"
    
    if [ -f "$manifest_file" ]; then
        echo "Processing $manifest_file"
        
        # Create a backup
        cp "$manifest_file" "${manifest_file}.bak"
        
        # Remove package attribute from manifest tag
        sed -i '' 's/<manifest[[:space:]]*package="[^"]*"/<manifest/g' "$manifest_file"
        
        echo "Fixed manifest: $manifest_file"
    else
        echo "Manifest file not found: $manifest_file"
    fi
}

# Fix manifests for all plugins
fix_manifest "audioplayers_android-4.0.3"
fix_manifest "device_info_plus-9.1.2"
fix_manifest "connectivity_plus-5.0.2"
fix_manifest "firebase_auth-4.20.0"
fix_manifest "firebase_core-2.32.0" 