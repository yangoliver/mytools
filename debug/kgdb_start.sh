#!/bin/bash

# The default setting is based on my macbook settings, need to be changed per new env
CONSOLE_IP="172.16.124.1"
CONSOLE_PORT="9999"

# The default setting is based on my centos 7.2 VM, need to be changed per new env
AGENT_PROXY=~/agent-proxy/agent-proxy
DEBUG_KERNEL=/usr/lib/debug/lib/modules/3.10.0-327.el7.x86_64/vmlinux

if [ -f ${AGENT_PROXY} ]; then
	${AGENT_PROXY} 2223^2222 ${CONSOLE_IP} ${CONSOLE_PORT} &
else
	echo "Download source code and build the tool first"
	cd ~;git clone http://git.kernel.org/pub/scm/utils/kernel/kgdb/agent-proxy.git;make all
	echo "Build complete...please run this tool again"
fi

echo "####Hints to use kgdb####"
echo "Please telnet 127.0.0.1 2223 for console access"
echo "Enter kgdb could use: echo g > /proc/sysrq-trigger on target machine"
echo "Start gdb client, please make sure you installed linux gdb"
echo "Use this gdb command to connect: target remote 127.0.0.1:2222"
echo "Dedailed information, see: http://oliveryang.net/2015/08/using-kgdb-debug-linux-kernel-2"
echo "####Hints to use kgdb####"

if [ -f ${DEBUG_KERNEL} ]; then
	gdb ${DEBUG_KERNEL}
else
	echo "Please download debug kernel"
fi
