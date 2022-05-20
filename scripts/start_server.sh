#!/bin/bash

# Makes sure the ec2-user's bash settings are loaded.
# This is needed to set the PATH to the correct value.
# See https://stackoverflow.com/a/34066708.
source /home/ec2-user/.bash_profile

# Goes to the directory to which CodeDeploy has copied our application files
# (it unzips them for us as well).
# This path is chosen by us and defined in the appspec.yml file.
cd /var/acebook

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash
. ~/.nvm/nvm.sh
nvm install node 16

nvm install v10.13.0
# Starts the server.
# The `> /dev/null 2> /dev/null < /dev/null &` bit is needed to start the process in the background.
# For an explanation of why it needs to be started in the background,
# as well as why writing something lik `npm start &` is not enough,
# see https://docs.aws.amazon.com/codedeploy/latest/userguide/troubleshooting-deployments.html#troubleshooting-long-running-processes.
npm start > /dev/null 2> /dev/null < /dev/null &
