# -*- coding: utf-8 -*-
#
# Created by Nils Herde on 27/03/16
#
# Script for pruning Windows server backup (wbadmin) backups from one or many destionations.
#
# Usage:
# Set log path
# Make sure your python installation matches the architecture of wbadmin.exe (32 vs 64 bit)
# Set the number of versions you want to keep on the backup destination
# Make sure the disk volumes matches your destinations.
# Add schedualed task for pruning

import logging
import subprocess
import sys


logger = logging.getLogger('backup-pruner')
log_path = "D:\\Arkiv\\backup-pruning\\"
logging.basicConfig(filename=log_path + 'backup-pruner.log', level=logging.DEBUG,
                    format='%(asctime)s %(levelname)s %(name)s:%(lineno)s %(message)s')
# path to Windows server backup
path = "C:\\Windows\\System32\\wbadmin.exe"
# Number of versions to keep on backup destinations
versions = 20
# Volume is what wbadmin needs for pruning. The DISK_XX label and day is for logging physical matching.
# Because paths are awkward on Windows there is an escape back slash before every back slash
disks = {
    'DISK_01': {'day': 'mandag', 'volume': '\\\\?\\Volume{557998A3-CF50-4139-80E1-2A8161A823D7}\\'},
    'DISK_02': {'day': 'torsdag', 'volume': '‪\\\\?\\Volume{35AE4FBC-8730-4434-A988-F0A440492B5A}\\'},
    'DISK_03': {'day': 'onsdag', 'volume': '\\\\?\\Volume{8BEDB394-42E0-4DE6-9EBA-9361E2C16B19}\\'},
    'DISK_04': {'day': 'fredag1', 'volume': '\\\\?\\Volume{F7FD0E0B-5014-4DB8-9CB5-0EEA3F47C569}\\'},
    'DISK_05': {'day': 'tirsdag', 'volume': '\\\\?\\Volume{594520BD-731A-41F6-A828-C4080B2900EC}\\'},
    'DISK_06': {'day': 'fredag4', 'volume': '\\\\?\\Volume{42EA4024-DC7F-4174-A067-3032A46181EC}\\'},
    'DISK_07': {'day': 'fredag3', 'volume': '\\\\?\\Volume{45D5B995-5EFD-4233-A31A-027FBEB782EC}\\'},
    'DISK_08': {'day': 'fredag2', 'volume': '\\\\?\\Volume{BC9243FF-302C-4E7C-8A65-F93BAE134D59}\\'},
}


def main():
    for disk in disks:
        # Subprocess Popen takes command with arguments as a list of strings
        cmd = [path, "delete", "backup", "-keepVersions:%s" % versions,
               "-backupTarget:%s" % disks[disk]['volume'], "-quiet"]
        logger.info(disk + ' started job')
        # Dispatch subprocess to perform pruning
        job = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE)
        # Now we wait for termination
        job.wait()
        # This returncode is wbadmins way of saying destination is not mounted
        # This is expected unless all targets are mounted at all times (rotating backup destionations)
        if job.returncode == 4294967294:
            logger.debug(disk + ' is not mounted')
        # Successfully terminated process
        elif job.returncode == 0:
            # We're interested in the process output for logging
            for line in job.stdout:
                logger.debug(line.decode("utf-8").rstrip('\n'))
            logger.info(disk + ' backups successfully pruned down to %s' % versions)
        # Something else happened (what). Let's log that.
        else:
            logger.warning('wbadmin exited with exit code: ' + job.returncode)
            exit(code=1)

main()
exit(code=0)
