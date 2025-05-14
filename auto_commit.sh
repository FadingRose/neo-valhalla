#!/bin/bash

cd ~/.config/nvim

# Get the current date and time
commit_message=$(date +"%Y-%m-%d %H:%M:%S")

# Perform git operations
git add .
git commit -m "$commit_message"
git pull --rebase
git push
