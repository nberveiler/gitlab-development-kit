# Local network binding

`gdk.test` is the standard for referring to the local GDK instance in documentation steps and GDK
tools. We recommend [mapping this to a loopback interface](#create-loopback-interface), but
it can be mapped to `127.0.0.1`.

To set up `gdk.test` as a hostname (assumes `172.16.123.1` is available):

1. Map `gdk.test` to `172.16.123.1`. For example, add the following to `/etc/hosts`:

   ```plaintext
   172.16.123.1 gdk.test
   ```

1. Add the following to `gdk.yml`:

   ```yaml
   hostname: gdk.test
   ```

1. Reconfigure GDK:

   ```shell
   gdk reconfigure
   ```

1. Restart GDK to use the new configuration:

   ```shell
   gdk restart
   ```

## Create loopback interface

Some functionality may not work if GDK processes listen on `localhost` or `127.0.0.1` (for example,
services running under Docker). Therefore, an IP address on a different private network should be
used.

`172.16.123.1` is a useful [private network address](https://en.wikipedia.org/wiki/Private_network#Private_IPv4_addresses)
that can avoid clashes with `localhost` and `127.0.0.1`. To configure a loopback interface for this
address:

1. Create an internal interface. On macOS, this adds an alias IP `172.16.123.1` to the loopback
   adapter:

   ```shell
   sudo ifconfig lo0 alias 172.16.123.1
   ```

   On Linux, you can create a dummy interface:

   ```shell
   sudo ip link add dummy0 type dummy
   sudo ip address add 172.16.123.1 dev dummy0
   sudo ip link set dummy0 up
   ```

1. In `config/gitlab.yml`, set the `host` parameter to `172.16.123.1`, or configure `gdk.test`.

For this to work across reboots, the aliased IP address command must be run at startup. To
automate this on macOS, create a file called `org.gitlab1.ifconfig.plist` at `/Library/LaunchDaemons/`
containing:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>org.gitlab1.ifconfig</string>
    <key>RunAtLoad</key>
    <true/>
    <key>Nice</key>
    <integer>10</integer>
    <key>ProgramArguments</key>
    <array>
      <string>/sbin/ifconfig</string>
      <string>lo0</string>
      <string>alias</string>
      <string>172.16.123.1</string>
    </array>
</dict>
</plist>
```

The method to persist this dummy interface on Linux varies between distributions. On Ubuntu 20.04,
you can run:

```shell
sudo nmcli connection add type dummy ifname dummy0 ip4 172.16.123.1
```
