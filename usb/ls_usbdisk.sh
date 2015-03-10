#!/bin/bash

# Declaration of *array* 'USBKEYS'
USBKEYS=($(
	grep -Hv ^0$ /sys/block/*/removable |       # search for *not 0* in `removable` flag of all devices
	sed s/removable:.*$/device\\/uevent/ |      # replace `removable` by `device/uevent` on each line of previous answer
	xargs grep -H ^DRIVER=sd |                  # search for devices drived by `SD`
	sed s/device.uevent.*$/size/ |              # replace `device/uevent` by 'size'
	xargs grep -Hv ^0$ |                        # search for devices having NOT 0 size
	cut -d / -f 4                               # return only 4th part `/` separated
))

# Print header
printf "DISK NAME\tMODEL\n"

# Print each usb disks
for dev in ${USBKEYS[@]} ;do		# for each devices in USBKEY...
	model=$(sed -e s/\ *$//g </sys/block/${dev}/device/model)
	printf "/dev/${dev}\t${model}\n"
done
