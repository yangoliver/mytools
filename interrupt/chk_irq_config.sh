#!/bin/bash

usage(){
	echo "Usage: $0 vector_name"
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

cpu_num=`grep processor /proc/cpuinfo| wc -l`
irqlist=`grep $VECT /proc/interrupts | awk -F: '{print $1}'`

function get_vect_name {

	grep "$1:" /proc/interrupts | awk -F" " \
	    '{if (NF-'"$cpu_num"'>3){print $1$(NF-1)$NF}else{print $1$NF}}'
}

function dump_irq_smp_affinity {

	printf "Dump /proc/irq/<irq>/smp_affinity for each irq\n"
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

function dump_nzero_irq_affinity_hint {

	printf "Dump non-zero /proc/irq/<irq>/affinity_hint for each irq\n"
	for irq in $irqlist
	do
	    hint_list=`cat /proc/irq/$irq/affinity_hint | \
		    awk -F"," '{for(i=1;i<=NF;i++){printf ("%d\n",$i)}}'`
		for hint in $hint_list
		do 
			if [ $hint -gt 0 ]
			then
				name=`get_vect_name $irq`
				value=`cat /proc/irq/$irq/affinity_hint`
				
				printf "%30s %40s\n" $name $value
				break
			fi
		done
	done;
}

function dump_irq_numa_node {

	printf "Dump /proc/irq/<irq>/node for each irq\n"
	for irq in $irqlist
	do
		name=`get_vect_name $irq`
		value=`cat /proc/irq/$irq/node`
		
		printf "%30s %40s\n" $name $value
	done;
}

dump_irq_smp_affinity
dump_nzero_irq_affinity_hint
dump_irq_numa_node
