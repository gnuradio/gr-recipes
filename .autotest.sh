#!/bin/bash

# Pull most recent master into this branch

git pull origin master -q
dimage="pybombs/pybombs-prefix"
dtag="latest"
drun="docker run --rm -it -v $(pwd):/root/.pybombs/recipes/gr-recipes $dimage:$dtag"

pbversion=`$drun pybombs --version`
pyversion=`$drun python --version`
imgversion=`docker images --filter=reference="$dimage" --format={{.Repository}}:{{.Tag}}:{{.Digest}} | grep $dtag | sed "s/^.*sha256://"`

for recipefile in *.lwr; do
	rname=`echo $recipefile | sed "s/.lwr$//"`
	rversion=`git log $recipefile | head -n 1 | sed "s/commit //"`
	echo "Testing installation of $rname"
	$drun pybombs -vy install $rname > .autotest.log
	if [ $? -eq 0 ]; then
    	echo $rname OK
	else
		# Installation failed
		issuetitle="Error installing $rname@${rversion:0:7} (autotest)"
		echo ".autotest.sh found an issue while attempting to install **[$rname](../../blob/master/$recipefile)** (last changed in commit [#${rversion:0:7}](https://github.com/gnuradio/gr-recipes/commit/$rversion))." > .autotest.issue
		echo "" >> .autotest.issue
		echo "## Setup used:" >> .autotest.issue
		echo "" >> .autotest.issue
		echo " - Docker image: $dimage:$dtag ([Explore](https://hub.docker.com/layers/$dimage/$dtag/images/sha256-$imgversion?context=explore) | [Tags](https://hub.docker.com/r/$dimage/tags))" >> .autotest.issue
		echo " - PyBOMBS version: $pbversion" >> .autotest.issue
		echo " - Python version: $pyversion" >> .autotest.issue
		echo "" >> .autotest.issue
		echo "## Install log:" >> .autotest.issue
		echo '```bash' >> .autotest.issue
		cat .autotest.log >> .autotest.issue
		echo '```' >> .autotest.issue
		echo $issuetitle
		cat .autotest.issue
	fi
	echo ""
done


