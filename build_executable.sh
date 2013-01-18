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
checkSVNSuccess=`egrep "revision" $logFile`


# pre-build commands:
echo ">> Clearing out last night's logs..."
echo "" > $logFile
echo "" > $errorLogFile

echo ">> Cleaning up last night's build..."
cd $buildPath
rm -rf *.app
cd ../

if [ -d $clientPath ]; then
	cd $clientPath
	rm $masterTourSWF
	rm -rf $finalAppPath
	cd ../../
fi

if [ -d $gearheadPath ]; then
	cd $gearheadPath
	rm *.swf
	cd ../../../../../
fi

# check that an sdk is included
# TODO
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
newVersion=`echo $checkSVNSuccess | awk -F"revision " '{print $2}' | awk -F"." '{print $1}'`
echo ">> Version from SVN is: $newVersion"

if [ ! -n "$newVersion" ]; then
	echo $logFile >> $errorLogFile
	exit 1
fi


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
	# TODO
done


# compile the main mtdclient swf file
echo ">> Compiling Master Tour..."
cd $clientPath
../../$amxmlcPath -compatibility-version=3.0.0 -managers flash.fonts.AFEFontManager -load-config+=../../config.xml ../../$mainMXML >> ../../$logFile

# verify the main.swf file was created
# TODO


# package and build the app
echo ">> Bundling MasterTour.app..."
../../$adtPath -package -storetype PKCS12 -keystore ../../$certPath -storepass $signingCertPassword -target bundle "MasterTour-"$version".app" ../../main-app.xml $masterTourSWF $assetsPath $iconsPath


# move the package to the root's build folder
echo ">> Moving app to build folder..."
mv "MasterTour-"$version".app" ../../build/"MasterTour-"$version".app"

echo "Nightly Build Complete.\n\n"

