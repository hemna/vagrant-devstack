#!/usr/bin/env python

import shlex, subprocess

proc = subprocess.Popen(['pip', 'freeze'], stdout=subprocess.PIPE)
pkgs = subprocess.Popen(['grep', 'dev'], stdin=proc.stdout, stdout=subprocess.PIPE)

pbyt = pkgs.communicate()[0]
plist = pbyt.split('\n')

for item in plist:
    pkg = item.split('=')[0]
    uproc = subprocess.Popen(['sudo', 'pip', 'uninstall', '-y', pkg])
    uproc.wait()

print('\n\nUninstall of dev version packages completed.')

for item in plist:
    if not item:
        continue
    pkg = item.split('=')[0]
    uproc = subprocess.Popen(['sudo', 'pip', 'install', pkg])
    uproc.wait()

print('\n\nReinstallation of removed packages completed.')
