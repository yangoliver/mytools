#!/bin/bash

LINE=$(git remote | grep "^upstream$" | wc -l)

if (($LINE != 1)); then
	printf "Error: please setup upstream branch fist\n"
fi

git fetch upstream

git merge upstream/master
