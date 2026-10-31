#!/usr/bin/env python3
"""A minimal BlueZ on a private bus, for testing scripts/bluetooth-agent.py.

Exports an adapter (/org/bluez/hci0), the agent manager (/org/bluez) and
three devices whose Pair asks the registered agent something:
  dev_22  RequestConfirmation(123456): paired if confirmed, else Rejected
  dev_33  RequestPinCode: paired if the PIN is "0000"
  dev_44  times out (AuthenticationTimeout)
Every call is printed as "CALL <method> <path> <args>" for the test.
Usage: fake_bluez.py (on the bus named by DBUS_SESSION_BUS_ADDRESS)
"""
import sys

from gi.repository import Gio, GLib

XML = """
<node>
  <interface name="org.freedesktop.DBus.ObjectManager">
    <method name="GetManagedObjects"><arg direction="out" type="a{oa{sa{sv}}}"/></method>
  </interface>
  <interface name="org.bluez.AgentManager1">
    <method name="RegisterAgent"><arg direction="in" type="o"/><arg direction="in" type="s"/></method>
    <method name="RequestDefaultAgent"><arg direction="in" type="o"/></method>
  </interface>
  <interface name="org.bluez.Adapter1">
    <method name="StartDiscovery"/><method name="StopDiscovery"/>
  </interface>
  <interface name="org.bluez.Device1">
    <method name="Pair"/><method name="CancelPairing"/><method name="Connect"/>
  </interface>
  <interface name="org.freedesktop.DBus.Properties">
    <method name="Set"><arg direction="in" type="s"/><arg direction="in" type="s"/><arg direction="in" type="v"/></method>
  </interface>
</node>
"""
NODE = Gio.DBusNodeInfo.new_for_xml(XML)
IFACES = {i.name: i for i in NODE.interfaces}
agent = {"sender": None, "path": None}


def log(*parts):
	print("CALL", *parts, flush=True)


def ask_agent(bus, method, args, reply_type, done):
	def finished(conn, result):
		try:
			done(conn.call_finish(result))
		except GLib.Error as e:
			done(e)
	bus.call(agent["sender"], agent["path"], "org.bluez.Agent1", method, args, reply_type,
		Gio.DBusCallFlags.NONE, 10000, None, finished)


def on_call(bus, sender, path, interface, method, params, invocation):
	log(method, path, params.print_(False) if params is not None else "()")
	if method == "GetManagedObjects":
		invocation.return_value(GLib.Variant("(a{oa{sa{sv}}})", ({
			"/org/bluez/hci0": {"org.bluez.Adapter1": {"Powered": GLib.Variant("b", True)}},
		},)))
	elif method == "RegisterAgent":
		agent["sender"], agent["path"] = sender, params.unpack()[0]
		invocation.return_value(None)
	elif method == "Pair" and path.endswith("dev_22"):
		def done(result):
			if isinstance(result, GLib.Error):
				invocation.return_dbus_error("org.bluez.Error.AuthenticationRejected", "rejected")
			else:
				invocation.return_value(None)
		ask_agent(bus, "RequestConfirmation", GLib.Variant("(ou)", (path, 123456)), None, done)
	elif method == "Pair" and path.endswith("dev_33"):
		def done(result):
			if not isinstance(result, GLib.Error) and result.unpack()[0] == "0000":
				invocation.return_value(None)
			else:
				invocation.return_dbus_error("org.bluez.Error.AuthenticationFailed", "wrong pin")
		ask_agent(bus, "RequestPinCode", GLib.Variant("(o)", (path,)), GLib.VariantType("(s)"), done)
	elif method == "Pair":
		invocation.return_dbus_error("org.bluez.Error.AuthenticationTimeout", "timed out")
	else:
		invocation.return_value(None)


def on_bus(bus, name):
	for path, names in (("/", ["org.freedesktop.DBus.ObjectManager"]),
			("/org/bluez", ["org.bluez.AgentManager1"]),
			("/org/bluez/hci0", ["org.bluez.Adapter1"]),
			("/org/bluez/hci0/dev_22", ["org.bluez.Device1", "org.freedesktop.DBus.Properties"]),
			("/org/bluez/hci0/dev_33", ["org.bluez.Device1", "org.freedesktop.DBus.Properties"]),
			("/org/bluez/hci0/dev_44", ["org.bluez.Device1", "org.freedesktop.DBus.Properties"])):
		for iface in names:
			bus.register_object(path, IFACES[iface], on_call, None, None)


def on_name(bus, name):
	print("READY", flush=True)


Gio.bus_own_name(Gio.BusType.SESSION, "org.bluez", Gio.BusNameOwnerFlags.NONE, on_bus, on_name, lambda *a: sys.exit(1))
GLib.MainLoop().run()
