#!/bin/bash

TIME=$(date +"%Y%m%d_%H%M%S")
TMP_DIR=/dev/shm
LOG_DIR=${HOME}/cpustat_${TIME}_$$_logs

PS_LOG=${TMP_DIR}/ps_${TIME}_$$.log
SCHE_DEBUG_LOG=${TMP_DIR}/sched_debug_${TIME}_$$.log
SCHESTAT_BEFORE_LOG=${TMP_DIR}/schedstat_before_${TIME}_$$.log
SCHESTAT_AFTER_LOG=${TMP_DIR}/schedstat_after_${TIME}_$$.log
SCHESTAT_PS_BEFORE_LOG=${TMP_DIR}/schedstat_ps_before_${TIME}_$$.log
SCHESTAT_PS_AFTER_LOG=${TMP_DIR}/schedstat_ps_after_${TIME}_$$.log

SAR_LOG=${TMP_DIR}/sar_${TIME}_$$.log
MPSTAT_LOG=${TMP_DIR}/mpstat_${TIME}_$$.log
IRQSTAT_LOG=${TMP_DIR}/irqstat_${TIME}_$$.log
PIDSTAT_LOG=${TMP_DIR}/pidstat_${TIME}_$$.log

SAR_PID=${TMP_DIR}/sar_${TIME}_$$.pid
MPSTAT_PID=${TMP_DIR}/mpstat_${TIME}_$$.pid
IRQSTAT_PID=${TMP_DIR}/irqstat_${TIME}_$$.pid
PIDSTAT_PID=${TMP_DIR}/pidstat_${TIME}_$$.pid

STAT_EXIT=0

usage(){
	printf "Usage: $0 [interval]"
	exit 1
}

function file_create {

	if [ ! -f $1 ]
	then
		touch $1
	fi
}

function dir_create {

	if [ ! -d $1 ]
	then
		mkdir $1
	fi
}

function dump_pid_list_schedstat {

	file_create $2

	for pid in $1
	do
		printf "********SCHEDSTAT_for_$pid************\n" >> $2
		date >> $2
		echo "cat /proc/$pid/sched" >> $2
		cat /proc/$pid/sched >> $2
		echo "cat /proc/$pid/schedstat" >> $2
		cat /proc/$pid/schedstat >> $2
		echo "\n\n" >> $2
	done
}

function exec_cmd {

	eval "$1  2>&1 &"
	echo $! > $2
}

function kill_cmd {

	kill -9 `cat $1`

	if [ $? -eq 0 ]
	then
		rm -f $1
	fi
}

function dump_schedstat {

	file_create $1

	date >> $1
	cat /proc/schedstat >> $1
}

function dump_sched_debug {

	printf "dump /proc/sched_debug into ${SCHE_DEBUG_LOG}\n"

	file_create ${SCHE_DEBUG_LOG}

	date >> ${SCHE_DEBUG_LOG}
	cat /proc/sched_debug >> ${SCHE_DEBUG_LOG}
	echo "*******************" >> ${SCHE_DEBUG_LOG}
	echo "\n\n" >> ${SCHE_DEBUG_LOG}
}

function dump_sched_debug_loop {

	while true
	do
		dump_sched_debug
		sleep 30
	done
}

function collect_logs {

	dir_create $LOG_DIR

	cp -f $TMP_DIR/*_${TIME}_$$* $LOG_DIR
}

trap 'trap_exit' SIGINT SIGQUIT SIGHUP

trap_exit()
{
	printf "Hitted Ctrl-C/Ctrl-\, or received SIGHUP. Now exiting..\n"

	dump_schedstat ${SCHESTAT_AFTER_LOG}

	dump_pid_list_schedstat "$USR_PID_LIST" ${SCHESTAT_PS_AFTER_LOG}
	dump_pid_list_schedstat "$KERN_PID_LIST" ${SCHESTAT_PS_AFTER_LOG}

	kill_cmd $SAR_PID
	kill_cmd $MPSTAT_PID
	kill_cmd $IRQSTAT_PID
	kill_cmd $PIDSTAT_PID

	collect_logs

	exit
}



[[ $# -gt 1 ]] && usage

if [ x$1 != x ]
then
	INTERVAL=$1
else
	INTERVAL=10
fi

printf "Dump system process by crash tool\n"

echo ps | crash > ${PS_LOG}

printf "Get target process pid\n"

USR_PID_LIST=`grep ddfs ${PS_LOG} | awk '{print $1}'`
KERN_PID_LIST=`grep dd_dg1/ppart0 ${PS_LOG} | awk '{print $1}'`

dump_pid_list_schedstat "$USR_PID_LIST" ${SCHESTAT_PS_BEFORE_LOG}
dump_pid_list_schedstat "$KERN_PID_LIST" ${SCHESTAT_PS_BEFORE_LOG}

dump_schedstat ${SCHESTAT_BEFORE_LOG}

exec_cmd "sar -q ${INTERVAL} > ${SAR_LOG}" $SAR_PID
exec_cmd "mpstat -u -I SUM -P ALL ${INTERVAL} > ${MPSTAT_LOG}" $MPSTAT_PID
exec_cmd "irqstat -b -r 40 -t ${INTERVAL} > ${IRQSTAT_LOG}" $IRQSTAT_PID
exec_cmd "pidstat -C 'dd_dg1' ${INTERVAL} > ${PIDSTAT_LOG}" $PIDSTAT_PID


dump_sched_debug_loop
