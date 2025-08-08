#!/bin/bash

# Create Xcode project for iSquareDesk
# This script creates a basic iOS app project structure

PROJECT_NAME="iSquareDesk"
BUNDLE_ID="com.squaredesk.iSquareDesk"

# Create project structure
mkdir -p "$PROJECT_NAME/$PROJECT_NAME"
mkdir -p "$PROJECT_NAME/$PROJECT_NAME.xcodeproj"
mkdir -p "$PROJECT_NAME/$PROJECT_NAME/Assets.xcassets"
mkdir -p "$PROJECT_NAME/$PROJECT_NAME/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$PROJECT_NAME/$PROJECT_NAME/Assets.xcassets/AccentColor.colorset"
mkdir -p "$PROJECT_NAME/$PROJECT_NAME/Preview Content"
mkdir -p "$PROJECT_NAME/$PROJECT_NAME/Preview Content/Preview Assets.xcassets"

echo "Project structure created. Please open Xcode and:"
echo "1. Create a new project"
echo "2. Choose iOS > App"
echo "3. Product Name: $PROJECT_NAME"
echo "4. Team: Select your team"
echo "5. Organization Identifier: com.squaredesk"
echo "6. Interface: SwiftUI"
echo "7. Language: Swift"
echo "8. Save in the iSquareDesk folder"
echo ""
echo "This will create a proper Xcode project with all necessary configurations."