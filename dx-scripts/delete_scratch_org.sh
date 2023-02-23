#!/bin/bash
#use this command when deleting a scratch org

if [ $# -lt 1 ]
then
    echo Usage: delete_scratch_org.sh alias
    exit
fi

#delete the scratch org with no prompt
sfdx force:org:delete -p -u $1;

#cleanup old info files
# rm scratch_org_info.json
# rm scratch_user_info*.json
# rm scratch_auth_info.json