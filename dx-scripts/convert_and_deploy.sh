#!/bin/bash


if [ $# -lt 1 ]
then
    echo Usage: convert_and_deploy.sh alias
    exit
fi

#cleanup
rm -rf deploy 

sfdx force:source:convert -r force-app/main/default/ -d deploy


./dx-scripts/deploy.sh $1