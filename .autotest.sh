#!/bin/bash

# Pull most recent master into this branch
git pull origin master

# Define some important values
dimage="pybombs/pybombs-prefix"
dtag="latest"
drun="docker run --rm -it -v $(pwd):/root/.pybombs/recipes/gr-recipes -v $(pwd)/.build:/pybombs/src: $dimage:$dtag"
pbversion=`$drun pybombs --version | tr -d '\r'`
pyversion=`$drun python3 --version | tr -d '\r'`
imgversion=`docker images --filter=reference="$dimage" --format={{.Repository}}:{{.Tag}}:{{.Digest}} | grep $dtag | sed "s/^.*sha256://"`

function autotest_reset () {
	mkdir -p .build
	rm -rf .build/*

}

function autotest_clean () {
	rm -f .autotest_*.issue
	rm -f .autotest_*.log
	rm -rf .build
}

# Testing function for an individual recipe
function run_test () {
	recipefile=${1:-}
	rname=`echo $recipefile | sed "s/.lwr$//"`
	rversion=`git log $recipefile | head -n 1 | sed "s/commit //"`
	printf "    Testing installation of $rname ($recipefile @ ${rversion:0:7}) ... "
	$drun pybombs -vy install $rname > .autotest_${rname}.log
	if [ $? -eq 0 ]; then
		# Installation succeeded, nothing to do
    		echo "OK"
	else
		# Installation failed
		issuetopic="$rname@${rversion:0:7} (PyBOMBS v$pbversion, Python v$pyversion)"
		echo "FAILED"
    	echo "            $issuetopic installation error"
		issuehash=`echo "$issuetopic" | md5sum | cut -c1-5`
		gh issue list --limit 999 | grep "autotest:$issuehash" > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			printf "            Issue is known:\n              -> Issue "
			gh issue list --limit 999 | grep "autotest:$issuehash"
		else
			issuetitle="Error installing $issuetopic [autotest:$issuehash]"
			echo ".autotest.sh found an issue while attempting to install $rname from **[$recipefile @ commit ${rversion:0:7}](https://github.com/gnuradio/gr-recipes/blob/$rversion/$recipefile)** ([commit diff for ${rversion:0:7}](https://github.com/gnuradio/gr-recipes/commit/$rversion))." >> .autotest_${rname}.issue
			echo "" >> .autotest_${rname}.issue
			echo "## Setup used:" >> .autotest_${rname}.issue
			echo "" >> .autotest_${rname}.issue
			echo " - Docker image: $dimage:$dtag ([Explore](https://hub.docker.com/layers/$dimage/$dtag/images/sha256-$imgversion?context=explore) | [Tags](https://hub.docker.com/r/$dimage/tags))" >> .autotest_${rname}.issue
			echo " - PyBOMBS version: $pbversion" >> .autotest_${rname}.issue
			echo " - Python version: $pyversion" >> .autotest_${rname}.issue
			echo "" >> .autotest_${rname}.issue
			echo "## Install details:" >> .autotest_${rname}.issue
			gistinput="gh gist create .autotest_${rname}.log"
			if [ -f ".build/${rname}/build/CMakeFiles/CMakeError.log" ]; then
				gistinput="${gistinput} .build/${rname}/build/CMakeFiles/CMakeError.log"
			fi
			if [ -f ".build/${rname}/build/CMakeFiles/CMakeOutput.log" ]; then
				gistinput="${gistinput} .build/${rname}/build/CMakeFiles/CMakeOutput.log"
			fi
			gistoutput=`$gistinput 2> /dev/null`
			echo $gistoutput >> .autotest_${rname}.issue
			echo "## Meta:" >> .autotest_${rname}.issue
			echo "This report has been created using the autotest script described in #200." >> .autotest_${rname}.issue
			export issuebody=$(cat .autotest_${rname}.issue)
			issuecreated=`gh issue create -t "${issuetitle}" -b "$issuebody" 2> /dev/null`
			echo "              -> Issue created: $issuecreated"
		fi
	fi
	echo ""
}

# Run tests either on all recipes in the directory, or on an individual recipe
# provided as an arument.
autotest_clean >/dev/null 2>&1
if [ $# -eq 0 ]; then
	echo "Running install tests on all files in `pwd`..."
	for recipefile in *.lwr; do
		autotest_reset >/dev/null 2>&1
		run_test $recipefile
	done
else
	echo "Running install tests on $1..."
	run_test $1
fi

