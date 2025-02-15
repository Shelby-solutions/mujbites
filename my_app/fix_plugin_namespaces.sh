#!/bin/bash

# Function to fix namespace in build.gradle
fix_namespace() {
  local plugin_dir="$1"
  local package_name="$2"
  local build_gradle="$plugin_dir/android/build.gradle"
  
  if [ -f "$build_gradle" ]; then
    # Check if android block exists
    if grep -q "android {" "$build_gradle"; then
      # Add namespace if not already present
      if ! grep -q "namespace" "$build_gradle"; then
        sed -i '' '/android {/a\
    namespace '"'$package_name'"'' "$build_gradle"
      fi
    fi
  fi
}

# Fix namespaces for each plugin
fix_namespace ".pub-cache/hosted/pub.dev/audioplayers_android-4.0.3" "xyz.luan.audioplayers"
fix_namespace ".pub-cache/hosted/pub.dev/device_info_plus-9.1.2" "dev.fluttercommunity.plus.device_info"
fix_namespace ".pub-cache/hosted/pub.dev/connectivity_plus-5.0.2" "dev.fluttercommunity.plus.connectivity"
fix_namespace ".pub-cache/hosted/pub.dev/firebase_auth-4.20.0" "io.flutter.plugins.firebase.auth"
fix_namespace ".pub-cache/hosted/pub.dev/firebase_core-2.32.0" "io.flutter.plugins.firebase.core" 