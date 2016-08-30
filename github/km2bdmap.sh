#!/bin/bash

usage(){
	echo "Usage: $0 [*.md]"
	exit 1
}

[[ $# -eq 0 ]] && usage

if [ x$1 != x ]
then
	FILE_MD=$1
else
	echo "***Error: Need a device vector name"
	usage
fi

FILE_TXT="${FILE_MD}.txt"

grep -E "^- |^ .*- " ${FILE_MD} | sed "s/- //g" | sed "s/  /    /g" > ${FILE_TXT}

echo "File has been converted into ${FILE_TXT}"
