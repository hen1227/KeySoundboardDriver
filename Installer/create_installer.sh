#!/usr/bin/env bash

# Creates installer for different channel versions.
# Run this script from the local BlackHole repo's root directory.
# If this script is not executable from the Terminal, 
# it may need execute permissions first by running this command:
#   chmod +x create_installer.sh

driverName="KeySoundboard"
driverFileName="BlackHole"
devTeamID="5BHAWQJGY5" # Replace this with your own developer team ID
devTeamProfile="Developer ID Installer: Henry Abrahamsen (5BHAWQJGY5)"
notarize=true # To skip notarization, set this to false
notarizeProfile="notarize" # Replace this with your own notarytool keychain profile name

############################################################################

# Basic Validation
if [ ! -d BlackHole.xcodeproj ]; then
    echo "This script must be run from the BlackHole repo root folder."
    echo "For example:"
    echo "  cd /path/to/BlackHole"
    echo "  ./Installer/create_installer.sh"
    exit 1
fi

version=`cat VERSION`

# Version Validation
if [ -z "$version" ]; then
    echo "Could not find version number. VERSION file is missing from repo root or is empty."
    exit 1
fi

for channels in 2; do # Modify as needed for other channel counts like 16, 64, 128, 256
    # Env
    ch=$channels"ch"
    driverVariantName=$driverName
    bundleID="com.henhen1227.KeySounboard.Driver"

    # Clean build directory
    rm -rf build/
    mkdir -p build/

    # Build
    xcodebuild \
      -project BlackHole.xcodeproj \
      -configuration Release \
      -target BlackHole CONFIGURATION_BUILD_DIR=build \
      PRODUCT_BUNDLE_IDENTIFIER=$bundleID \
      GCC_PREPROCESSOR_DEFINITIONS='$GCC_PREPROCESSOR_DEFINITIONS
      kNumber_Of_Channels='$channels'
      kPlugIn_BundleID=\"'$bundleID'\"
      kDriver_Name=\"'$driverName'\"'

    # Check if build was successful
    if [ ! -d "build/$driverFileName.driver" ]; then
        echo "Build failed: $driverFileName.driver not found."
        exit 1
    fi

#   pause 'Press [Enter] key to continue...'
    read -r -p "Press enter to continue"


    # Sign the built driver
    codesign \
      --force \
      --deep \
      --options runtime \
      --sign $devTeamID \
      --timestamp \
      build/$driverFileName.driver

    # Package
    pkgbuild \
      --sign "$devTeamProfile" \
      --root build/$driverFileName.driver \
      --scripts Installer/Scripts \
      --identifier $bundleID \
      --version "$version" \
      --install-location /Library/Audio/Plug-Ins/HAL/"$driverName".driver \
      build/"$driverVariantName".pkg

    # Create distribution XML for productbuild
    distributionXML=distribution.xml
    echo "<?xml version=\"1.0\" encoding='utf-8'?>
    <installer-gui-script minSpecVersion='2'>
        <title>$driverVariantName: Audio Loopback Driver ($ch) $version</title>
        <welcome file='welcome.html'/>
        <license file='../LICENSE'/>
        <conclusion file='conclusion.html'/>
        <options customize='never' require-scripts='false' hostArchitectures='x86_64,arm64'/>
        <pkg-ref id=\"$bundleID\"/>
        <choices-outline>
            <line choice=\"$bundleID\"/>
        </choices-outline>
        <choice id=\"$bundleID\" visible='true' title=\"$driverVariantName $ch\" start_selected='true'>
            <pkg-ref id=\"$bundleID\"/>
        </choice>
        <pkg-ref id=\"$bundleID\" version=\"$version\" onConclusion='none'>build/$driverVariantName.pkg</pkg-ref>
    </installer-gui-script>" > $distributionXML

    # Build installer package
    installerPkgName="$driverVariantName-$version.pkg"

    productbuild \
      --sign "$devTeamProfile" \
      --distribution $distributionXML \
      --resources Installer/ \
      --package-path build \
      "$installerPkgName"  # Corrected output file specification

    # Check if the installer package was created
    if [ ! -f "$installerPkgName" ]; then
        echo "Error: Installer package not found."
        exit 1
    fi

    rm $distributionXML

    # Notarize and Staple
    if [ "$notarize" = true ]; then
        xcrun \
          notarytool submit "$installerPkgName" \
          --team-id $devTeamID \
          --progress \
          --wait \
          --keychain-profile $notarizeProfile

        xcrun stapler staple "$installerPkgName"
    fi
done
