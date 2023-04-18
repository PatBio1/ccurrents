#!/bin/bash
# use this command to run all package unit tests
# 

#if no arguments, then run in default scratch org
if [ $# -lt 1 ]
then
    echo Running tests in default scratch org
    sfdx force:apex:test:run  -y -l RunLocalTests --wait 60 --resultformat tap --codecoverage -d test_results;
    sleep 5;
    ./dx-scripts/parse_test_results.js
    exit
fi

#otherwise run tests in specified username or alias org
sfdx force:apex:test:run -y -l RunLocalTests -r human --wait 60 --verbose -u $1