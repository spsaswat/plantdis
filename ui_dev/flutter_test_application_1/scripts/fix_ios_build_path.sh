#!/bin/bash
# Fix: Flutter expect build/ios/iphoneos but Xcode output Release-iphoneos
# after flutter run --release or flutter build ios , if can't find Runner.app, run this script
set -e
cd "$(dirname "$0")/.."
IOS_BUILD="build/ios"
if [ -d "$IOS_BUILD/Release-iphoneos" ] && [ ! -d "$IOS_BUILD/iphoneos" ]; then
  ln -sf Release-iphoneos "$IOS_BUILD/iphoneos"
  echo "Created symlink: $IOS_BUILD/iphoneos -> Release-iphoneos"
elif [ -L "$IOS_BUILD/iphoneos" ]; then
  echo "Symlink already exists: $IOS_BUILD/iphoneos"
else
  echo "Release-iphoneos not found. Run 'flutter build ios' or 'flutter run --release' first."
fi
