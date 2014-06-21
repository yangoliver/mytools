#!/bin/bash

FILE=/proc/interrupts

usage(){
	echo "Usage: $0 vector_name [interrupts file]"
	exit 1
}

[[ $# -eq 0 ]] && usage


if [ x$1 != x ]
then
	DEV=$1
else
	echo "***Error: Need a device vector name"
	usage
fi

if [ x$2 != x ]
then
	FILE=$2
else
	echo "No file specified, will use $FILE by default"
fi

output=$(awk 'NR==1 {
	dev_count = 0

	if ( $1 == "CPU0") {
		core_count = NF
		for (i = 1; i <= core_count; i++)
			names[i-1] = $i
		next
	} else {
		core_count = NF-3
		for (i = 0; i <= core_count; i++)
			names[i] = "CPU"i
	}
}
/'"$DEV"'/ {
	if (NF-core_count>3) {
		dev[dev_count++] = $(NF-1) $NF
	} else {
		dev[dev_count++] = $NF
	}

	for (i = 2; i <= 2+core_count; i++)
		totals[i-2] += $i
}

END {
	if (dev_count == 0) {
		printf("The device vector (%s) is not found\n", '"$DEV"')
		exit 1
	}

	printf("DEVICES:")
	for (i = 0; i < dev_count; i++)
		printf("%s ", dev[i])
	printf("[begin]\n")
	for (i = 0; i < core_count; i++)
		printf("%s=%d\n", names[i], totals[i])
	printf("DEVICES:")
	for (i = 0; i < dev_count; i++)
		printf("%s ", dev[i])
	printf("[end]\n")
}
' ${FILE})

echo "${output}"
