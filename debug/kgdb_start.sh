#!/bin/bash

# The default setting is based on my macbook settings, need to be changed per new env
CONSOLE_IP="172.16.124.1"
CONSOLE_PORT="9999"

# The default setting is based on my centos 7.2 VM, need to be changed per new env
HOME=~
AGENT_HOME=${HOME}/agent-proxy
AGENT_PROXY=${HOME}/agent-proxy/agent-proxy
DEBUG_KERNEL=/usr/lib/debug/lib/modules/`uname -r`/vmlinux

if [ -f ${AGENT_PROXY} ]; then
	PID=`pidof agent-proxy`
	if [ ${PID} -ne 0 ]; then
		kill -9 $PID
	fi
	${AGENT_PROXY} 2223^2222 ${CONSOLE_IP} ${CONSOLE_PORT} &
else
	echo "Download source code and build the tool first"
	cd ${HOME};git clone http://git.kernel.org/pub/scm/utils/kernel/kgdb/agent-proxy.git;
	cd ${AGENT_HOME};make all
	echo "Build complete...please run this tool again"
	exit 0
fi

echo "####Hints to use kgdb on target machine####"
echo "echo 'kbd,ttyS0' > /sys/module/kgdboc/parameters/kgdboc"
echo "echo g > /proc/sysrq-trigger"
echo ""
echo "####Hints to use kgdb on client####"
echo "Please telnet 127.0.0.1 2223 for console access"
echo "Start gdb client, please make sure you installed linux gdb"
echo "Use this gdb command to connect: target remote 127.0.0.1:2222"
echo "Dedailed information, see: http://oliveryang.net/2015/08/using-kgdb-debug-linux-kernel-2"

if [ -f ${DEBUG_KERNEL} ]; then
	gdb ${DEBUG_KERNEL}
else
	echo "Please download debug kernel"
fi