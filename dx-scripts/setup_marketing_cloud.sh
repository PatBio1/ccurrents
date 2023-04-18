#!/bin/bash


sfdx package install --package MarketingCloud -w 10 --no-prompt

sfdx force:source:convert -r force-app/main/ -d deploy

./dx-scripts/deploy.sh $1