# Read the wiki!
All critical developer documentation supporting our work is available [here in our wiki](https://github.com/CCurrents/proesis/wiki). 

For all work items, tracking, please refer to our [Proesis Build Project](https://github.com/orgs/CCurrents/projects/1) here. 

## Developer Notes

### A decent overview of the workflow for our devops:
  0. These steps require you are setup on our github repo and have oauth'd into CircleCI.
  1. Pull a new project directory via git clone, done often until you feel more confident about your git skillz.
  ```git clone https://github.com/CCurrents/proesis.git```
  3. Be sure you have a default Dev Hub set:
  ```./set_default_dev_hub.sh```
  5. Next, we'll kick off a series of actions by running:
  ```./create_branch.sh <working-branch-name>```
  - This will create your new working branch from _integration_, _and_ 
  - spin up a scratch org (w sample data if available), _and_ 
  - push your new working branch to the your new scratch org
  8. The fresh scratch org will automatically open in your default browser
  9. Do your coding in vscode etc. then:
  ```force:source:push``` to your scratch org
  10. Do your admin config stuff in your scratch org, then:
  ``` sfdx force:source:pull``` from the scratch org to local _working branch_
  12. Carefully choose what you stage and commit to your local _working branch_
  13. Then ```git push origin <working-branch-name>``` to your remote _working branch_ with cmd line or vscode github plugin
  14. This will kick off the Circle CI process which will spin up a fresh scratch org and push your working branch changes then run all tests (the CircleCI plugin for vscode is highly recommended)
  15. Once you are happy with the unit of work you have intact and the CircleCI build is successful, you can create a Pull Request that proposes to merge from your _working branch_ into _integration_
  17. You need at least one approving reviewer to move forward so choose a peer smarter than you to review, propose changes or approve
  18. Approval allows the PR to be merged if there are no conflicts, otherwise merge occurs after conflicts are resolved
  19. Other team members pull changes from _integration_ via direct pull and merge into their own branch or `git clone` as in #1 above.
  20. Repeat the circle of life.

  _Enjoy!_
