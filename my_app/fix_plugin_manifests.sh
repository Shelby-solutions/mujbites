#!/bin/bash

# Function to fix AndroidManifest.xml
fix_manifest() {
  local plugin_dir="$1"
  local manifest_file="$plugin_dir/android/src/main/AndroidManifest.xml"
  
  if [ -f "$manifest_file" ]; then
    # Remove package attribute from manifest tag
    sed -i '' 's/package="[^"]*"//g' "$manifest_file"
  fi
}

# Fix manifests for each plugin
fix_manifest ".pub-cache/hosted/pub.dev/audioplayers_android-4.0.3"
fix_manifest ".pub-cache/hosted/pub.dev/device_info_plus-9.1.2"
fix_manifest ".pub-cache/hosted/pub.dev/connectivity_plus-5.0.2"
fix_manifest ".pub-cache/hosted/pub.dev/firebase_auth-4.20.0"
fix_manifest ".pub-cache/hosted/pub.dev/firebase_core-2.32.0" 