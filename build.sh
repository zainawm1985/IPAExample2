#!/usr/bin/env bash
# IPA 示例程序打包脚本
# 依赖：macOS + Xcode + XcodeGen (brew install xcodegen)
# 用法：./build.sh
set -euo pipefail

PROJECT_NAME="IPAExample"
SCHEME="IPAExample"
CONFIGURATION="Release"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$PROJECT_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"

echo "==> 生成 Xcode 工程 (xcodegen generate)"
xcodegen generate

echo "==> Archive (xcodebuild archive)"
xcodebuild archive \
  -project "$PROJECT_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=iOS" \
  CODE_SIGN_STYLE=Automatic

echo "==> Export .ipa (xcodebuild -exportArchive)"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "ExportOptions.plist" \
  -exportPath "$EXPORT_DIR"

echo "==> 完成"
echo "ipa 产出路径：$EXPORT_DIR/$PROJECT_NAME.ipa"
