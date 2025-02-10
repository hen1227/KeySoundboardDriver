#!/bin/bash

# Define variables
driverIdentifier="com.henhen1227.audio.driver.uninstaller"
version="1.0"
packageName="AudioDriverUninstaller.pkg"
scriptsFolder="Scripts"
postinstallScript="postinstall.sh"

# Create the scripts directory and ensure it's empty
mkdir -p "$scriptsFolder"
echo "Creating scripts directory..."

# Make sure the postinstall script is executable
chmod +x "$postinstallScript"

# Copy the postinstall script into the scripts directory
cp "$postinstallScript" "$scriptsFolder/postinstall"
echo "Configured postinstall script."

# Use pkgbuild to create the uninstaller package
pkgbuild --identifier "$driverIdentifier" \
         --nopayload \
         --scripts "$scriptsFolder" \
         --version "$version" \
         "$packageName"

echo "Uninstaller package $packageName has been created."