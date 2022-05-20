#!/bin/bash

# `pgrep node` Finds the process IDs of all currently running node processes
# '| xargs' feeds those IDs throught to ...
# `kill -9`, which terminates the processes. 
#
# This is a very blunt way to stop our server.
# It's not great because for a short time our server won't be running at all 
# until the new one is started again by the `start_server.sh` script.
# There are better ways! Do some research or ask a coach if you're interested
# (hint: look into process managers, e.g. pm2).
pgrep node | xargs kill -9

