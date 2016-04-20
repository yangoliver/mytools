#!/bin/bash

# The default setting is based on my macbook settings, need to be changed per new env
CONSOLE_IP="172.16.124.1"
CONSOLE_PORT="9999"

# The default setting is based on my centos 7.2 VM, need to be changed per new env
HOME=~
AGENT_HOME=${HOME}/agent-proxy
AGENT_PROXY=${HOME}/agent-proxy/agent-proxy
# For self build kernel
# DEBUG_DIR=/lib/modules/`uname -r`/build
# For RHEL/CentOS/Fedora by default
DEBUG_DIR=/usr/lib/debug/lib/modules/`uname -r`
VMLINUX=vmlinux
DEBUG_KERNEL=${DEBUG_DIR}/${VMLINUX}
GDB_PY=${DEBUG_DIR}/vmlinux-gdb.py

if [ x$1 != x ] ;then
	DEBUG_KERNEL = $1
fi

if [ ! -f ${DEBUG_KERNEL} ]; then
	echo "Can not find debug kernel at ${DEBUG_KERNEL}"
	echo "Please specify debug kernel path or set DEBUG_KERNEL variable"
	exit 1
fi

# Generating .gdbinit file...
if [ -f ${GDB_PY} ] && [ ! -f ~/.gdbinit ]; then
	echo "python gdb.COMPLETE_EXPRESSION = gdb.COMPLETE_SYMBOL" > ~/.gdbinit
	echo "add-auto-load-safe-path ${DEBUG_DIR}/vmlinux-gdb.py" >> ~/.gdbinit
fi

if [ -f ${AGENT_PROXY} ]; then
	PID=`pidof agent-proxy`
	if [ $? -eq 0 ]; then
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

# The vmlinux-gdb.py requires enter the debug dir first, then gdb vmlinux
cd ${DEBUG_DIR}; gdb ${VMLINUX}

exit 0
