#!/bin/bash
# use this command when creating a new branch 
# from current checked-out branch

if [ $# -lt 1 ]
then
    echo Usage: create_branch.sh branchname
    exit
fi

#create new branch from current branch
git checkout -b $1;


#push branch to github, starting CI build
git push -u origin $1


# call setup script for org setup
echo Setting up scratch org...patience please...
./dx-scripts/setup_scratch.sh $1;