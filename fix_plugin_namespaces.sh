#!/bin/bash

# Function to fix namespace in build.gradle
fix_namespace() {
    local plugin_dir="$1"
    local package_name="$2"
    local build_gradle="$HOME/.pub-cache/hosted/pub.dev/$plugin_dir/android/build.gradle"
    
    if [ -f "$build_gradle" ]; then
        echo "Processing $build_gradle"
        
        # Create a backup
        cp "$build_gradle" "${build_gradle}.bak"
        
        # Check if android block exists and add namespace if not present
        if grep -q "android {" "$build_gradle"; then
            if ! grep -q "namespace" "$build_gradle"; then
                # Use temp file for sed on macOS
                sed -i '' '/android {/a\
    namespace "'"$package_name"'"' "$build_gradle"
                echo "Added namespace to $build_gradle"
            else
                echo "Namespace already exists in $build_gradle"
            fi
        else
            echo "No android block found in $build_gradle"
        fi
    else
        echo "Build.gradle not found: $build_gradle"
    fi
}

# Fix namespaces for all plugins
fix_namespace "audioplayers_android-4.0.3" "xyz.luan.audioplayers"
fix_namespace "device_info_plus-9.1.2" "dev.fluttercommunity.plus.device_info"
fix_namespace "connectivity_plus-5.0.2" "dev.fluttercommunity.plus.connectivity"
fix_namespace "firebase_auth-4.20.0" "io.flutter.plugins.firebase.auth"
fix_namespace "firebase_core-2.32.0" "io.flutter.plugins.firebase.core" 