#!/bin/bash



#============= Nightly Build Script - Eventric 2013 ===============#

# global variables
repoDir="repo/"
clientPath="repo/src/"
buildPath="build/"
sdkPath="sdk/"
appXML="main-app.xml"
gearheadPath="repo/src/assets/skins/gearhead"
mxmlcPath="sdk/bin/mxmlc"
amxmlcPath="sdk/bin/amxmlc"
adtPath="sdk/bin/adt"
certPath="EventricCert.p12"
finalAppPath="MasterTour.app"
masterTourSWF="main.swf"
assetsPath="assets"
iconsPath="icons"
mainMXML="repo/src/main.mxml"
logFile="log.txt"
errorLogFile="errorlog.txt"
repoUsername=$1
repoPassword=$2
signingCertPassword=$3


# pre-build commands:
echo ">> Clearing out last night's logs..."
echo "" > $logFile
echo "" > $errorLogFile

echo ">> Cleaning up last night's build..."
cd $buildPath
rm -rf *.tar.gz
cd ../

if [ -d $clientPath ]; then
	cd $clientPath
	rm $masterTourSWF
	rm -rf *.app
	rm -rf $finalAppPath
	cd ../../
fi

if [ -d $gearheadPath ]; then
	cd $gearheadPath
	rm *.swf
	cd ../../../../../
fi

# check that an sdk is included
if [ ! -d "$sdkPath/bin" ]; then
	echo "Flex SDK is missing or corrupted, the build cannot continue. Exiting Build..." >> $errorLogFile
	echo "Flex SDK is missing or corrupted, the build cannot continue. Exiting Build..."
	exit 1
fi

chmod -R 0777 $sdkPath


# check if the repo has been checked out before:
cd $repoDir
if [ -d "src" ]; then
	echo ">> Running SVN Update..."
	svn up >> "../"$logFile
else
	# otherwise, check it out freshly
	echo ">> Checking out fresh from SVN..."
	svn co https://eventric.svn.beanstalkapp.com/mtdclient/trunk/mastertour --username $repoUsername --password $repoPassword . >> "../"$logFile
fi
cd ..

# verify svn worked properly
checkSVNSuccess=`egrep "revision" $logFile`
newVersion=`echo $checkSVNSuccess | awk -F"revision " '{print $2}' | awk -F"." '{print $1}'`

if [ ! -n "$newVersion" ]; then
	echo "Value of SVN's version was: $newVersion, which is invalid. Exiting build..."  >> $errorLogFile
	echo "Value of SVN's version was: $newVersion, which is invalid. Exiting build..."
	exit 1
fi

echo ">> Version from SVN is: $newVersion"


# find and replace the version number with the new version
echo ">> Opening main-app.xml for write, updating the versionNumber for the app..."
# chmod -R 0777 $clientPath
currentVersion=`egrep "<versionNumber>" $appXML`
version=`echo $currentVersion | awk -F"<versionNumber>" '{print $2}' | awk -F"</versionNumber>" '{print $1}'`
find $appXML -type f | xargs perl -pi -e "s/"$version"/"1.2.$newVersion"/g"
echo ">> App version number updated to $version"


# compile all style sheets into accessible swf files
echo ">> Compiling stylesheets..."
for css in `find $gearheadPath -name '*.css'`
do
	sh $mxmlcPath -compatibility-version=3.0.0 -load-config+=config.xml $css >> $logFile

	#verify the style sheet swf file was created
	rootName=$(echo $css | cut -d'.' -f 1)

	if [ ! -f "$rootName.swf" ]; then
		echo "$nameSplit was not created successfully. Exiting Build..." >> $errorLogFile
		echo "$nameSplit was not created successfully. Exiting Build..."
		exit 1
	fi
done


# compile the main mtdclient swf file
echo ">> Compiling Master Tour..."
cd $clientPath
sh ../../$amxmlcPath -compatibility-version=3.0.0 -managers flash.fonts.AFEFontManager -load-config+=../../config.xml ../../$mainMXML >> ../../$logFile

# verify the main.swf file was created
if [ ! -f $masterTourSWF ]; then
	echo "$masterTourSWF was not created successfully. Exiting Build..." >> $errorLogFile
	echo "$masterTourSWF was not created successfully. Exiting Build..."
	exit 1
fi


# package and build the app
echo ">> Bundling MasterTour.app..."
sh ../../$adtPath -package -storetype PKCS12 -keystore ../../$certPath -storepass $signingCertPassword -target bundle "MasterTour-"$version".app" ../../main-app.xml $masterTourSWF $assetsPath $iconsPath

# verify the MasterTour-(version).app file was created
if [ ! -d "MasterTour-"$version".app" ]; then
	echo "MasterTour-"$version".app was not created successfully. Exiting Build..." >> $errorLogFile
	echo "MasterTour-"$version".app was not created successfully. Exiting Build..."
	exit 1
fi

# HACK: This walks into the contents of MT.app and symbolically links the resources, otherwise they're triplicated,
# causing a build that's bloated to almost 2x it's normal size
chmod -R 777 "MasterTour-"$version".app"
cd "MasterTour-$version.app/Contents/Frameworks/Adobe AIR.framework"
rm -rf "$(pwd)/Resources"
chmod -R 777 "$(pwd)/Versions/1.0/Resources/"
echo ">> Linking $(pwd)/Versions/1.0/Resources/ subfolder..."
ln -s "$(pwd)/Versions/1.0/Resources/" "$(pwd)/Resources"
if [ ! -d "$(pwd)/Resources" ]; then
	echo ">> ERROR OCCURRED 2"
	rm -f "$(pwd)/Resources"
	ln -s "$(pwd)/Versions/1.0/Resources/" "$(pwd)/Resources"
fi

rm -rf "$(pwd)/Versions/Current"
chmod -R 777 "$(pwd)/Versions/1.0/"
echo ">> Linking $(pwd)/Versions/1.0/ subfolder..."
ln -s "$(pwd)/Versions/1.0/" "$(pwd)/Versions/Current"
if [ ! -d "$(pwd)/Versions/Current" ]; then
	echo ">> ERROR OCCURRED 2"
	rm -f "$(pwd)/Versions/Current"
	ln -s "$(pwd)/Versions/1.0/" "$(pwd)/Versions/Current"
fi
cd ../../../../
#TODO: check that these links exist


# code signing the app
echo ">> Code Signing the App..."
codesign -f -s "Developer ID Application: Eventric LLC" "MasterTour-"$version".app" >> ../../$logFile

echo ">> Zipping up MasterTour-$version.tar.gz..."
#productbuild --component "MasterTour-"$version".app" /Applications "MasterTour-"$version".pkg" --sign "Developer ID Installer: Eventric LLC" >> ../../$logFile
tar -zcvf ./MasterTour-$version.tar.gz MasterTour-$version.app/ >> ../../$logFile

if [ ! -f "MasterTour-"$version".tar.gz" ]; then
	echo "MasterTour-"$version".tar.gz was not created successfully. Exiting Build..." >> ../../$errorLogFile
	echo "MasterTour-"$version".tar.gz was not created successfully. Exiting Build..."
	exit 1
fi


# move the package to the root's build folder
echo ">> Moving app to build folder..."
mv "MasterTour-"$version".tar.gz" ../../build/"MasterTour-"$version".tar.gz"

if [ ! -f ../../build/MasterTour-$version.tar.gz ]; then
	echo "MasterTour-"$version".tar.gz was not moved from repo/src successfully. Exiting Build..." >> ../../$errorLogFile
	echo "MasterTour-"$version".tar.gz was not moved from repo/src successfully. Exiting Build..."
	exit 1
fi


echo "Nightly Build Complete.\n\n"

