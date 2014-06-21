#!/bin/bash

FILE=/proc/interrupts

usage(){
	echo "Usage: $0 cpu_id [interrupts file]"
	exit 1
}

[[ $# -eq 0 ]] && usage

if [ x$1 != x ]
then
	CPU_ID=$1
else
	echo "***Error: Need a valid core number"
	usage
fi

if [ x$2 != x ]
then
	FILE=$2
else
	echo "No file specified, will use $FILE by default"
fi

output=$(awk 'NR==1 {
	vec_count = 0

	A
	if ( $1 == "CPU0") {
		core_count = NF
		field_num = '"$CPU_ID"'+2
	vec_field = NF+3;
	} else {
		core_count = NF-3
		field_num = '"$CPU_ID"'+2
	vec_field = NF;
	}
	
	if ('"$CPU_ID"' > core_count) {
		printf("The cpu core number is not correct,it should be less than %d\n", core_count)
		exit 1
	}

		printf("%5s%20sCPU%d%22s\n","IRQ",CPU,'"$CPU_ID"',"Vector Name")
		printf("------------------------------------------------------------\n")
	
	if ( $1 == "CPU0") {
		next
	}
}
{
	vec_count++;
	printf("%5s%30d\t\t",$1,$field_num)
	for (i=vec_field;i<=NF;i++) {
		printf("%10s",$i)
	}
	printf("\n");
}
END {
	if (vec_count == 0) {
		printf("No records found, please check file:%s\n", '"$FILE"')
		exit 1
	}
}
' ${FILE})

echo "${output}"
