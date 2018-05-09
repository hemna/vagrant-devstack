#!/bin/bash

# It walks the list of known OpenStack projects
# and pulls down the latest from the master branch

DEST=${DEST:-/opt/stack}
UPDATE_LOG=$DEST/logs/git-update.log

repos=`ls -1 $DEST`

pushd $DEST
mv $UPDATE_LOG $UPDATE_LOG.old

err() {
    echo -e "\e[00;31mError:\e[00m $1"
}

for word in $repos; do
    master="master"
    gitdir="$word/.git"
    if [ -d "$gitdir" ]; then
        echo "Updating $word '$master' branch"
        cd $word;
        branch=`git rev-parse --abbrev-ref HEAD`
        if [[ $branch != $master ]]; then
            git co master >>$UPDATE_LOG 2>&1
        fi
        git pull origin master >>$UPDATE_LOG 2>&1
        if [[ $branch != $master ]]; then
            git checkout $branch >>$UPDATE_LOG 2>&1
        fi
        cd ..
    else 
        err "Skipping $DEST/$word. Not valid git repo"
    fi
done

popd
