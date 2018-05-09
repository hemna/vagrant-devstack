#!/usr/bin/env python

import argparse
import os
import logging
import subprocess
import sys
import tempfile

xml = ("<hostdev mode='subsystem' type='pci' managed='yes'><source>"
       "<address domain='0x0000' bus='0x%(bus_id)s' slot='0x%(slot_id)s' "
       "function='0x%(function_id)s'/></source></hostdev>")

LOG_FILENAME = 'pci_passthrough.log'

parser = argparse.ArgumentParser(
    description="Enable Fibre Channel HBA PCI Passthrough.  "
                "If a device isn't specified, you will be prompted.")
parser.add_argument('--all', default=False, dest='all_devices',
                    action='store_true',
                    help='Pass through all discovered FC PCI devices')
parser.add_argument('vmname',
                    help=('The libvirt VM name to give access to the'
                          'FC device(s).  Use "virsh list" to get the name'))
parser.add_argument('--device',
                    help=("The PCI bus ID of the device you want pass "
                          "through to the vm. (lspci -Dv) ie. 0000:05:00.2"))
parser.add_argument('--trial',
                    default=False, action='store_true',
                    help="Do a dry run.  Doesn't actually run virsh commands.")
parser.add_argument('--verbose', default=logging.info, action='store_true',
                    help="Turn on debug/verbose logging")

args = parser.parse_args()

if args.verbose:
    log_level = logging.DEBUG
else:
    log_level = logging.INFO

logging.basicConfig(level=log_level)
LOG = logging.getLogger("FC-PCI")
fh = logging.FileHandler(LOG_FILENAME)
formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
fh.setFormatter(formatter)
fh.setLevel(log_level)
LOG.addHandler(fh)
# Don't poop log output to console
LOG.propagate = False

def get_pci_devices():
    p = subprocess.Popen(['lspci', '-D', '-vv'], stdout=subprocess.PIPE)
    lspci_output, err = p.communicate()

    lines = lspci_output.split('\n')
    pci_devs = []
    entry = {}
    for line in lines:
        val = line.split()
        if val == []:
            pci_devs.append(entry)
            entry = {}
        else:
            if line[0] == '\t':
                foo = line.strip().split(':')
                if len(foo) == 2:
                    entry[foo[0]] = foo[1]
            else:
                entry['bus_id'] = val[0]
                subline = line[len(val[0]):].strip()
                info = subline.split(':')
                entry['type'] = info[0].strip()
                entry['info'] = info[1].strip()

    return pci_devs


def prompt_fc_device(fc_devs):
    prompt = ["0) Abort"]
    devices = {'0': None}
    count = 1
    for device in fc_devs:
        devices['%s' % count] = device
        question = ("%(count)s) %(name)s - %(pci_id)s" %
                    {"count": count, "name": device["info"],
                     "pci_id": device['bus_id']})
        prompt.append(question)
        count += 1

    print("\n".join(prompt))

    var = raw_input("Select which FC device you want to use: ")
    dev = None
    if var in devices:
        dev = devices[var]

    return dev


def parse_pci_bus_id(bus_id):
    device = {}
    dev_id = bus_id.split(':')

    device['domain_id'] = dev_id[0]
    device['bus_id'] = dev_id[1]
    extra = dev_id[2].split('.')
    device['slot_id'] = extra[0]
    device['function_id'] = extra[1]
    return device


def run_detach_fc_device(pci_id, trial=False):
    pci_device = ("pci_%(domain_id)s_%(bus_id)s_%(slot_id)s_%(function_id)s" %
                  pci_id)

    cmd = ['virsh', 'nodedev-detach', pci_device]
    if not trial:
        try:
            p = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE)
            out, err = p.communicate()
            if err:
                raise Exception(err)
        except Exception as ex:
            msg = "Failed to detach device %s" % ex
            raise Exception(msg)
    else:
        LOG.info("Detach virsh command '%s'" % " ".join(cmd))


def run_attach_fc_device(pci_id, xml, vmname, trial=False):
    # dump the xml to a file
    fileTemp = tempfile.NamedTemporaryFile(delete=False)
    LOG.debug("Temp file = %s" % fileTemp.name)
    attached = False
    try:
        fileTemp.write(xml)
        fileTemp.close()
        cmd = ['virsh', 'attach-device', vmname, fileTemp.name]
        if not trial:
            try:
                p = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                                     stderr=subprocess.PIPE)
                out, err = p.communicate()
                if err:
                    raise Exception(err)
                attached = True
            except Exception as ex:
                raise Exception("Failed to attach PCI device %s" % ex)
        else:
            LOG.info("Attach Device command '%s'" % " ".join(cmd))

    except Exception as ex:
        LOG.error(ex)
        print(ex)

    finally:
        if attached:
            os.remove(fileTemp.name)


def get_fc_device(device_id, fc_devices):
    """Try and find a user supplied PCI id in the list of FC devices."""
    device = None
    for dev in fc_devices:
        if device_id == dev['bus_id']:
            device = dev

    return device


def run_pci_passthrough(vmname, devices, trial=False):
    LOG.debug("doing passthrough for %s devices" % len(devices))
    for device in devices:
        pci_id = parse_pci_bus_id(device['bus_id'])
        build_xml = (xml % {'bus_id': pci_id['bus_id'],
                            'slot_id': pci_id['slot_id'],
                            'function_id': pci_id['function_id']})
        LOG.debug("PCI xml:%s" % build_xml)
        try:
            run_detach_fc_device(pci_id, trial)
            run_attach_fc_device(pci_id, build_xml, vmname, trial)
        except Exception as ex:
            LOG.error("Failure: '%s'" % ex)
            print(ex)


pci_devs = get_pci_devices()

fc_devices = []
for dev in pci_devs:
    if 'type' in dev and dev['type'] == 'Fibre Channel':
        fc_devices.append(dev)

if args.all_devices:
    run_pci_passthrough(args.vmname, fc_devices, args.trial)
else:
    if args.device:
        device = get_fc_device(args.device, fc_devices)
    else:
        device = prompt_fc_device(fc_devices)

    if device:
        LOG.info("Using device %s" % device['bus_id'])
    else:
        msg = "No valid FC device selected.  aborting"
        print(msg)
        LOG.error(msg)
        sys.exit()

    run_pci_passthrough(args.vmname, [device], args.trial)
