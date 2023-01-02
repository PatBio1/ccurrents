#!/bin/bash
# Exit script if a statement returns a non-true return value.
set -o errexit
# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

if [ $# -lt 1 ]
then
    echo Usage: set_default_scratch_org.sh alias
    exit
fi
sfdx force:config:set defaultdevhubusername=$1