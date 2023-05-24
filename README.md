# zabbix-update-info
This Repo contains:

wu-info.ps1
- This script creates a cache file with some windows updates statistics or returns the desired values from this cache file for use with zabbix (or any other monitoring system) See script for detailed infomation.

zbx-template-wuinfo.yaml
- This template retreives windows update info statistics created by the wu-info.ps1 script.

Items 
- Windows update updates-waiting: amount of not yet installed updated
- Windows update days-elapsed: amount of days since last update
- Windows update stats timestamp: timestamp of cached windows update information
- Windows update stats JSON: complete information, including installed updates list

Triggers:
- HIGH: Last update > 60 days, only triggerd when also updates-waiting > 0
- WARNING: Updates waiting > 0

zabbix_agent2.userparams.conf:
- contains required UserParams to be included in zabbix agent configuration file
