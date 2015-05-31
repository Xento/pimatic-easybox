pimatic-easybox
=======================

A plugin for detecting devices and missed calls through an Easybox 904x router (maybe other work, too)


Configuration
-------------
You can load the backend by editing your `config.json` to include:

    {
      "plugin": "easybox",
      "ip": "192.168.158.1",
      "password": "xxx",
      "interval": "120"
    }

My router hangs after some time, if I lower the interval, so be careful.

{
  "id": "iPhone",
  "name": "iPhone",
  "class": "EasyBoxDevicePresence",
  "hostname": "Mein iPhone"
}
You can detect your device via, hostname, ip or mac
	
in the `plugins` section. For all configuration options see 
[device-config-schema](easybox-config-schema.coffee)

Example:
--------

if missed call then pushover xxx

if devicename is present then
