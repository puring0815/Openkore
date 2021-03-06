#!/bin/bash
# This script creates a source tarball for OpenKore, confpack and tablepack.

PACKAGE=openkore
VERSION=1.9.1

DIRS=(.
	src
	src/build
	src/scons-local-0.96.91
	src/scons-local-0.96.91/SCons
	src/scons-local-0.96.91/SCons/Node
	src/scons-local-0.96.91/SCons/Optik
	src/scons-local-0.96.91/SCons/Options
	src/scons-local-0.96.91/SCons/Platform
	src/scons-local-0.96.91/SCons/Scanner
	src/scons-local-0.96.91/SCons/Script
	src/scons-local-0.96.91/SCons/Sig
	src/scons-local-0.96.91/SCons/Tool
	src/po
	src/test
	src/Actor
	src/AI
	src/Base
	src/Base/Server
	src/Base/WebServer
	src/IPC
	src/IPC/Manager
	src/Interface
	src/Interface/Console
	src/Interface/Console/Other
	src/Interface/Wx
	src/Interface/Wx/DockNotebook
	src/Network
	src/Network/Receive
	src/Poseidon
	src/Utils
	src/Utils/Core
	src/Utils/StartupNotification
	src/auto/XSTools
	src/auto/XSTools/misc
	src/auto/XSTools/pathfinding
	src/auto/XSTools/unix
	src/auto/XSTools/win32
	src/auto/XSTools/translation
	src/auto/XSTools/utils
	src/auto/XSTools/utils/win32
	src/auto/XSTools/utils/unix
	src/auto/XSTools/utils/c-bindings
	src/auto/XSTools/utils/perl
)
PACKAGEDIR=$PACKAGE-$VERSION


if [[ "$1" == "--help" ]]; then
	echo "makedist.sh [--bin]"
	echo " --bin    Create a binary distribution."
	exit 1
elif [[ "$1" == "--bin" ]]; then
	BINDIST=1
	if [[ "$2" == "-o" ]]; then
		PACKAGEDIR="$3"
	fi
fi

if [[ "$BINDIST" == "1" ]]; then
	for F in start.exe wxstart.exe NetRedirect.dll; do
		if [[ ! -f "$F" ]]; then
			echo "Please put $F in the current folder."
			exit 1
		fi
	done
fi

ADDITIONAL=()
if [[ "$BINDIST" != "1" ]]; then
	ADDITIONAL[${#ADDITIONAL[@]}]=SConstruct
	ADDITIONAL[${#ADDITIONAL[@]}]=SConscript
	ADDITIONAL[${#ADDITIONAL[@]}]=Distfiles
	ADDITIONAL[${#ADDITIONAL[@]}]=makedist.sh
fi

export GZIP=--best
export BZIP2=-9


# Bail out on error
err() {
	if [ "x$1" != "x" ]; then
		echo "*** Error: $1"
	else
		echo "*** Error"
	fi
	exit 1
}

# Preparation: create the dist folder
rm -rf "$PACKAGEDIR" || err
mkdir "$PACKAGEDIR"  || err


# Copy the files to the dist folder
process() {
	local TARGET="$PACKAGEDIR/$1/"
	local IFS=$'\n'
	local FILES=`cat "$1/Distfiles" 2>/dev/null | sed 's/\r//g'`

	echo "# Processing $1 :"
	if ! [ -d "$TARGET" ]; then
		mkdir -p "$TARGET" || err
	fi
	for F in "${ADDITIONAL[@]}"; do
		if [ -f "$1/$F" ]; then
			echo "Copying $1/$F"
			cp "$1/$F" "$TARGET" || err
		fi
	done

	for F in ${FILES[@]}; do
		echo "Copying $1/$F"
		cp "$1/$F" "$TARGET" || err
	done
}

for D in ${DIRS[@]}; do
	process "$D"
done


#######################################


# Copy the confpack and tablepack files to the distribution's folder
function findConfpackDir() {
	if [[ -d confpack ]]; then
		confpackDir=confpack
	elif [[ -d control/confpack ]]; then
		confpackDir=control/confpack
	elif [[ -d ../confpack ]]; then
		confpackDir=../confpack
	else
		err "Cannot find the confpack folder. Please put it in the current directory."
	fi
}

function findTablepackDir() {
	if [[ -d tablepack ]]; then
		tablepackDir=tablepack
	elif [[ -d tables/tablepack ]]; then
		tablepackDir=tables/tablepack
	elif [[ -d ../tablepack ]]; then
		tablepackDir=../tablepack
	else
		err "Cannot find the tablepack folder. Please put it in the current directory."
	fi
}

dir=`cd "$PACKAGEDIR"; pwd`
findConfpackDir
findTablepackDir
make -C "$confpackDir" distdir DISTDIR="$dir/control" || err
make -C "$tablepackDir" distdir DISTDIR="$dir/tables" || err

# Convert openkore.pl to Unix line format, otherwise Unix users can't
# execute it directly.
perl src/build/dos2unix.pl "$PACKAGEDIR/openkore.pl" || err
perl "$confpackDir/unix2dos.pl" "$PACKAGEDIR/News.txt" || err

if [[ "$BINDIST" == "1" ]]; then
	# Create binary zipfile
	cp XSTools.dll NetRedirect.dll "$PACKAGEDIR/src/auto/XSTools/" || err

	# Win32 binary
	cp start.exe "$PACKAGEDIR/" || err
	zip -9r "$PACKAGE-$VERSION-win32.zip" "$PACKAGEDIR" || err

	# Win32 Wx binary
	cp wxstart.exe "$PACKAGEDIR/" || err
	rm -f "$PACKAGEDIR/start.exe"
	zip -9r "$PACKAGE-wx-$VERSION.zip" "$PACKAGEDIR" || err

	echo "$PACKAGE-$VERSION-win32.zip created"
	echo "$PACKAGE-wx-$VERSION.zip created"

else
	# Create tarball
	echo "Creating distribution archive..."
	tar --bzip2 -cf "$PACKAGEDIR.tar.bz2" "$PACKAGEDIR" || err
	echo "$PACKAGEDIR.tar.bz2"
fi

rm -rf "$PACKAGEDIR"
