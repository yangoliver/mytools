#!/bin/bash

usage(){
	echo "Usage: $0 vector_name [interval]"
	exit 1
}

[[ $# -eq 0 ]] && usage

if [ x$1 != x ]
then
	VECT=$1
else
	echo "***Error: Need a device vector name"
	usage
fi

if [ x$2 != x ]
then
	INTERVAL=$2
else
	INTERVAL=5
fi

vect_num=`echo $VECT | awk -F":" '{print NF}'`

if [ $vect_num -gt 1 ]
then
	vect_array=(`echo $VECT | awk -F":" '{for(i=1;i<=NF;i++){print $i}}'`)
else
	vect_array=($VECT)
fi

cpu_num=`grep processor /proc/cpuinfo| wc -l`


function get_vect_name {

	grep "$1:" /proc/interrupts | awk -F" " \
	    '{if (NF-'"$cpu_num"'>3){print $1$(NF-1)$NF}else{print $1$NF}}'
}

function dump_irq_smp_affinity {

	irqlist=`grep $1 /proc/interrupts | awk -F: '{print $1}'`
	printf "\n"
	for irq in $irqlist
	do
		name=`get_vect_name $irq`
		value=`cat /proc/irq/$irq/smp_affinity`
		
		if [ -f /proc/irq/$irq/smp_affinity_list ]
		then
			cpu_list=`cat /proc/irq/$irq/smp_affinity_list`
			printf "%30s %40s CPU %s\n" $name $value $cpu_list
		else
			printf "%30s %40s\n" $name $value
		fi
	done;
}

echo "Current vector filter is "${vect_array[@]}""
echo "Interval is $INTERVAL, use CTRL+C to quit..."

while (true)
do
	for ((i=0;i<${#vect_array[@]};i++))
	do
		dump_irq_smp_affinity ${vect_array[$i]}
	done

	sleep $INTERVAL
done;
