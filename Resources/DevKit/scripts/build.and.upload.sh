#!/bin/zsh

cd "$(dirname "$0")"

while [[ ! -d .git ]] && [[ "$(pwd)" != "/" ]]; do
    cd ..
done

if [[ -d .git ]] && [[ -d FlowDown.xcworkspace ]]; then
    echo "[*] found project root: $(pwd)"
else
    echo "[!] could not find project root"
    exit 1
fi

PROJECT_ROOT=$(pwd)

./Resources/DevKit/scripts/scan.license.sh

export BUMP_VERSION_ALLOWED=NO

xcodebuild -workspace FlowDown.xcworkspace \
    -scheme FlowDown \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$PROJECT_ROOT/.build/FlowDown.xcarchive" \
    archive | xcbeautify

xcodebuild -workspace FlowDown.xcworkspace \
    -scheme FlowDown-Catalyst \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$PROJECT_ROOT/.build/FlowDown-Catalyst.xcarchive" \
    archive | xcbeautify

xcodebuild -exportArchive \
    -archivePath "$PROJECT_ROOT/.build/FlowDown.xcarchive" \
    -exportPath "$PROJECT_ROOT/.build/FlowDown.ipa" \
    -exportOptionsPlist "$PROJECT_ROOT/Resources/DevKit/scripts/export-options.plist" \
    -allowProvisioningUpdates

xcodebuild -exportArchive \
    -archivePath "$PROJECT_ROOT/.build/FlowDown-Catalyst.xcarchive" \
    -exportPath "$PROJECT_ROOT/.build/FlowDown-Catalyst.app" \
    -exportOptionsPlist "$PROJECT_ROOT/Resources/DevKit/scripts/export-options-catalyst.plist" \
    -allowProvisioningUpdates
