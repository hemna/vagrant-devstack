#!/usr/bin/python
"""
clean_disk_by_path.

This is a script to help cleaning out
luns in /dev/disk/by-path

"""
import argparse
import logging
import os
import sys

device_path = "/dev/disk/by-path"
logging.basicConfig(filename='clean_luns.log', level=logging.DEBUG)
ch = logging.StreamHandler(sys.stdout)
ch.setLevel(logging.INFO)
LOG = logging.getLogger()
LOG.addHandler(ch)


def get_devices():
    """Fetch the list of devices.

    This gets all the known devices from
    /dev/disk/by-path

    returns list

    """
    # look for all iscsi and fc devices to nuke
    try:
        device_list = list(os.walk(device_path))[0][-1]
    except IndexError:
        device_list = []
    return device_list


def remove_devices(device_list, remove_type="all", force=False):
    """Remove the luns.

    This tries to remove the luns that
    live in /dev/disk/by-path

    return None

    """
    for device in device_list:
        if '-scsi-' in device:
            LOG.debug("ignoring %s" % device)
            continue

        if "all" in remove_type:
            if not force:
                answer = ask_for_remove(device)
                if "yes" in answer:
                    remove_device(device)
                else:
                    LOG.info("NOT removing %s" % device)
            else:
                remove_device(device)

        elif ("fc" in remove_type and "-fc-" in device):
            if not force:
                answer = ask_for_remove(device)
                if "yes" in answer:
                    remove_device(device)
                else:
                    LOG.info("NOT removing FC device %s" % device)
            else:
                remove_device(device)

        elif ("iscsi" in remove_type and "-iscsi-" in device):
            if not force:
                answer = ask_for_remove(device)
                if "yes" in answer:
                    remove_device(device)
                else:
                    LOG.info("NOT removing iSCSI device %s" % device)
            else:
                remove_device(device)

    return None


def ask_for_remove(device):
    """Ask the user if they want to remove the device.

    returns string

    """
    answer = raw_input("Remove %s [yes/no]: " % device)
    if ("yes" not in answer and "no" not in answer):
        print("Invalid Input. Must be either yes or no")
        return ask_for_remove(device)
    return answer


def remove_device(device):
    dev_path = ("/dev/disk/by-path/%(device)s" %
                {'device': device})
    dev_path = os.path.realpath(dev_path)
    dev_name = dev_path.replace("/dev/", "")

    LOG.info("Removing %(device)s(%(name)s)"
             % {'device': device,
                'name': dev_name})
    cmd = ('echo "1" > /sys/block/%(device)s/device/delete' %
           {"device": dev_name})
    LOG.debug("issuing %(cmd)s" % {'cmd': cmd})
    result = os.system(cmd)
    LOG.debug("result = %s" % result)


parser = argparse.ArgumentParser(description="Clean out /dev/disk/by-path")
parser.add_argument('--force', default=False, action='store_true',
                    help="Don't prompt the deletion of each entry")
parser.add_argument('--type', default="All", type=str,
                    choices=["All", "all", "FC", "fc",
                             "iSCSI", "ISCSI", "iscsi"],
                    help="What type of devices to remove")

args = parser.parse_args()
devices = get_devices()
LOG.debug(devices)
remove_devices(devices, args.type.lower(), args.force)
