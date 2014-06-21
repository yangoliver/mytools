#!/bin/bash

BASE_DIR=`dirname $0`
CHK_INTR=${BASE_DIR}/chk_intr.sh
DUMP_INTR=${BASE_DIR}/dump_intr.sh

DELTA_THRES=10000
INTERVAL=5

usage(){
	echo -n "Usage: $0 vector file_interrupts_before file_interrupts_after"
	echo " [threshold] [interval]"
	exit 1
}

[[ $# -eq 0 ]] && usage

if [ x$1 != x ]
then
	VECT=$1
else
	usage
fi

if [ x$2 != x ]
then
	if [ x"$2" == x"/proc/interrupts" ]
	then
		cp /proc/interrupts /tmp/interrupts_before
		FILE1="/tmp/interrupts_before"
	else 
		FILE1=$2
	fi
else
	usage
fi

if [ x$5 != x ]
then
	INTERVAL=$5
fi

if [ x$3 != x ]
then
	if [ x"$2" == x"/proc/interrupts" ]
	then
		sleep $INTERVAL
		cp /proc/interrupts /tmp/interrupts_after
		FILE2="/tmp/interrupts_after"
	else 
		FILE2=$3
	fi
else
	usage
fi

if [ x$4 != x ]
then
	DELTA_THRES=$4
else
	echo "Calculate the interrupt diffs greater than $DELTA_THRES"
fi


array_before=(`$CHK_INTR $VECT $FILE1 | grep CPU| awk -F"=" '{print $2}'`)
array_after=(`$CHK_INTR $VECT $FILE2 | grep CPU | awk -F"=" '{print $2}'`)
array_cpu=()
intr_total=0

for ((i=0;i<${#array_before[@]};i++))
do

	if [ ${array_after[$i]} -lt ${array_before[$i]} ]
	then
		printf "\n\n\n"
		echo "***Error: the $FILE2 should be the interrupts_after file\n"
		printf "\n\n\n"
		usage
	fi

	delta=$((${array_after[$i]}-${array_before[$i]}))

	intr_total=$(($intr_total+$delta))

	printf "CPU%2d intr diff=%d\n" $i $delta

	if [ $delta -gt $DELTA_THRES ]
	then
		array_cpu[${#array_cpu[*]}]=$i
	fi

done

echo "Totoal interrupts deltas on all CPUs is $intr_total"

echo "CPU ${array_cpu[@]} has the significant interrupts number"

for ((i=0;i<${#array_cpu[@]};i++))
do

	array_cpu_vect=(`$DUMP_INTR ${array_cpu[$i]} $FILE1 | grep $VECT | \
	    awk -F" " '/[:]/{print $1$3}'`)
	array_cpu_before=(`$DUMP_INTR ${array_cpu[$i]} $FILE1 |  grep $VECT | \
	    awk -F" " '/[:]/{print $2}'`)
	array_cpu_after=(`$DUMP_INTR ${array_cpu[$i]} $FILE2 | grep $VECT | \
	    awk -F" " '/[:]/{print $2}'`)
	
	#echo "+++++++++++++++++++++++++++"
	#echo ${array_cpu_vect[@]}
	#echo ${array_cpu_before[@]}
	#echo ${array_cpu_after[@]}
	#echo "+++++++++++++++++++++++++++"
	
	for ((j=0;j<${#array_cpu_before[@]};j++))
	do

		#echo ${array_cpu_after[$j]}-${array_cpu_before[$j]}
		
		delta=$((${array_cpu_after[$j]}-${array_cpu_before[$j]}))

		if [ $delta -gt $DELTA_THRES ]
		then
			printf "On CPU%s %10s intr diff is=%d\n"  \
			    ${array_cpu[$i]} ${array_cpu_vect[$j]} $delta
		fi

	done

done
