#!/bin/bash
#
# Copyright (C) SUSE LINUX GmbH 2016, all rights reserved.
#
# This library is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation; either version 2.1 of the License, or
# (at your option) version 3.
#
# This library is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
# License for more details.
#
# provision and mount zram compressed ramdisks

RAPIDO_DIR="$(realpath -e ${0%/*})/.."
. "${RAPIDO_DIR}/runtime.vars"

set -x

function _zram_setup() {
	local zram_name=$1
	local zram_size=$2
	local zram_mnt=$3
	local zram_mnt_owner=$4
	local zram_dev="/dev/${zram_name}"

	if [ -d $zram_mnt ]; then
		mountpoint -q $zram_mnt && _fail "$zram_mnt already mounted"
	else
		mkdir -p $zram_mnt || _fail "$zram_mnt creation failed"
		chown $zram_mnt_owner $zram_mnt || _fail
	fi

	echo "${zram_size}" > /sys/block/$zram_name/disksize || _fail

	mkfs.xfs $zram_dev || _fail

	mount $zram_dev $zram_mnt || _fail
	chown $zram_mnt_owner $zram_mnt || _fail

	echo "mounted $zram_name for $zram_mnt_owner at $zram_mnt"
}

# get ownership of the ceph src dir so it can be applied to the mounted fses
owner=`stat --format="%U:%G" $CEPH_SRC` || _fail

num_zram_devs=1
[ -n "$ZRAM_VSTART_OUT_SIZE" ] && ((num_zram_devs++))
[ -n "$ZRAM_VSTART_DATA_SIZE" ] && ((num_zram_devs++))

modprobe zram num_devices="${num_zram_devs}" || _fail
zram_i=0

_zram_setup "zram${zram_i}" $ZRAM_INITRD_SIZE $ZRAM_INITRD_MNT $owner
((zram_i++))

# if running with a vstart.sh cluster, use zram for logs and data
if [ -n "$ZRAM_VSTART_OUT_SIZE" ]; then
	_zram_setup "zram${zram_i}" $ZRAM_VSTART_OUT_SIZE \
		    $ZRAM_VSTART_OUT_MNT $owner
	((zram_i++))
fi

if [ -n "$ZRAM_VSTART_DATA_SIZE" ]; then
	_zram_setup "zram${zram_i}" $ZRAM_VSTART_DATA_SIZE \
		    $ZRAM_VSTART_DATA_MNT $owner
	((zram_i++))
fi
