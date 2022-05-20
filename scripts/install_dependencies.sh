#!/bin/bash

# Makes sure the ec2-user's bash settings are loaded.
# This is needed to set the PATH to the correct value.
# See https://stackoverflow.com/a/34066708.
source /home/ec2-user/.bash_profile


# Goes to the directory to which CodeDeploy has copied our application files
# (it unzips them for us as well).
# This path is chosen by us and defined in the appspec.yml file.
cd /var/acebook

# Installs dependencies defined in package.json.
npm install
