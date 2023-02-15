# Read the wiki!
All critical developer documentation supporting our work is available [here in our wiki](https://github.com/CCurrents/proesis/wiki). 

For all work items, tracking, please refer to our [Proesis Build Project](https://github.com/orgs/CCurrents/projects/1) here. 

## Developer Notes

### quick setup
- setup proesis dev hub as your default devhub
- run `./dx-scripts/setup_scratch <scratch org alias>`

### A decent overview of the workflow for our devops:
  1. Pull a new project directory via git clone, done often until you feel more confident about your git skillz.
  2. Be sure you switch to the branch you want to base your new work from in vscode, usually _intqa_.
  3. Be sure you have a default Dev Hub set in your local sfdx config (done by `./set_default_dev_hub.sh`).
  4. You should create a new local _working branch_ before pulling the changed code back to local (use `./create_branch.sh _<working-branch-name>_`).
  5. Spin up a fresh scratch org paying attention to the `scratch-org-def` project file settings, and (also done by `./create_branch.sh`).
  6. `sfdx force:source:push` to the specific scratch org (included with above `./create_branch.sh`).
  7. Set up sample data in new scratch org (included with above with `setup_scratch.sh` via `create_branch.sh`).
  8. The fresh scratch org will automatically open (thanks again `create_branch.sh`!).
  9. Do your work in the scratch org including admin stuff as well as code stuff!
  10. Force:source:pull from the scratch org to local _working branch_.
  11. Carefully choose what you stage and commit to your local _working branch_.
  12. Then `git push` to your remote _working branch_.
  13. This will kick off the CI process which will spin up a fresh scratch org and push your working branch changes then run all tests (see CircleCI).
  14. Create a pull request that proposes to merge from your _working branch_ into _main_.
  15. A peer smarter than you reviews and approves merges into _main_.
  16. Other team members pull changes from _main_ by synch or `git clone` as in #1 above.
  17. Repeat the circle of life.

  _Enjoy!_
