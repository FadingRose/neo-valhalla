#!/bin/bash

# Get the current date and time
commit_message=$(date +"%Y-%m-%d %H:%M:%S")

# Add all changes to the staging area
git add .

# Commit the changes with the current date and time as the commit message
git commit -m "$commit_message"

# Push the changes to the remote repository
git push
