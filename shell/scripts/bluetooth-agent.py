#!/usr/bin/env python3
"""Bloom's Bluetooth session: discovery and the pairing agent for BlueZ.

The shell runs this while its "Add a device" view looks for devices or a
device pairs. Holding the bus connection keeps a discovery alive (BlueZ ends
a client's discovery when it leaves), and the process is the default agent,
so passkey prompts reach the panel.

Commands, one a line on stdin:
  scan on | scan off       start or stop looking for devices
  pair <device path>       pair, then trust and connect it
  answer yes | answer no   reply to a confirm prompt
  pin <code>               reply to a provide prompt
  cancel                   cancel the pairing in progress
Events, one JSON object a line on stdout:
  {"event": "ready"}
  {"event": "prompt", "kind": "confirm" | "display" | "provide", "pin": ...}
  {"event": "paired"}
  {"event": "failed", "error": "<D-Bus error name>"}

BLOOM_BT_BUS names a bus address to use instead of the system bus (tests).
"""
import json
import os
import sys

from gi.repository import Gio, GLib

BLUEZ = "org.bluez"
AGENT_PATH = "/org/bloom/BluetoothAgent"
AGENT_XML = """
<node>
  <interface name="org.bluez.Agent1">
    <method name="Release"/>
    <method name="RequestPinCode"><arg direction="in" type="o"/><arg direction="out" type="s"/></method>
    <method name="DisplayPinCode"><arg direction="in" type="o"/><arg direction="in" type="s"/></method>
    <method name="RequestPasskey"><arg direction="in" type="o"/><arg direction="out" type="u"/></method>
    <method name="DisplayPasskey"><arg direction="in" type="o"/><arg direction="in" type="u"/><arg direction="in" type="q"/></method>
    <method name="RequestConfirmation"><arg direction="in" type="o"/><arg direction="in" type="u"/></method>
    <method name="RequestAuthorization"><arg direction="in" type="o"/></method>
    <method name="AuthorizeService"><arg direction="in" type="o"/><arg direction="in" type="s"/></method>
    <method name="Cancel"/>
  </interface>
</node>
"""
PAIR_TIMEOUT_MS = 60000
CALL_TIMEOUT_MS = 20000


def emit(event, **fields):
	print(json.dumps(dict(event=event, **fields)), flush=True)


class Session:
	def __init__(self, bus):
		self.bus = bus
		self.adapter = None
		# The agent request waiting for the person: (kind, invocation).
		self.waiting = None
		self.pairing = None

	def call(self, path, interface, method, args, reply_type, callback, timeout=CALL_TIMEOUT_MS):
		self.bus.call(BLUEZ, path, interface, method, args, reply_type,
			Gio.DBusCallFlags.NONE, timeout, None, callback)

	# ---- startup ----

	def start(self):
		info = Gio.DBusNodeInfo.new_for_xml(AGENT_XML).interfaces[0]
		self.bus.register_object(AGENT_PATH, info, self.on_agent_call, None, None)
		result = self.bus.call_sync(BLUEZ, "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects",
			None, GLib.VariantType("(a{oa{sa{sv}}})"), Gio.DBusCallFlags.NONE, CALL_TIMEOUT_MS, None)
		for path, interfaces in result.unpack()[0].items():
			if "org.bluez.Adapter1" in interfaces:
				self.adapter = path
				break
		self.bus.call_sync(BLUEZ, "/org/bluez", "org.bluez.AgentManager1", "RegisterAgent",
			GLib.Variant("(os)", (AGENT_PATH, "KeyboardDisplay")), None, Gio.DBusCallFlags.NONE, CALL_TIMEOUT_MS, None)
		self.bus.call_sync(BLUEZ, "/org/bluez", "org.bluez.AgentManager1", "RequestDefaultAgent",
			GLib.Variant("(o)", (AGENT_PATH,)), None, Gio.DBusCallFlags.NONE, CALL_TIMEOUT_MS, None)
		emit("ready")

	# ---- commands ----

	def command(self, line):
		words = line.strip().split(" ", 1)
		verb, rest = words[0], (words[1] if len(words) > 1 else "")
		if verb == "scan" and self.adapter:
			method = "StartDiscovery" if rest == "on" else "StopDiscovery"
			self.call(self.adapter, "org.bluez.Adapter1", method, None, None, self.ignore)
		elif verb == "pair" and rest.startswith("/") and not self.pairing:
			self.pairing = rest
			self.call(rest, "org.bluez.Device1", "Pair", None, None, self.on_paired, PAIR_TIMEOUT_MS)
		elif verb == "answer" and self.waiting and self.waiting[0] == "confirm":
			self.reply(None if rest == "yes" else "org.bluez.Error.Rejected")
		elif verb == "pin" and self.waiting and self.waiting[0] in ("pin", "passkey"):
			kind = self.waiting[0]
			if kind == "passkey" and not (rest.isdigit() and int(rest) <= 999999):
				self.reply("org.bluez.Error.Rejected")
			else:
				self.reply(None, GLib.Variant("(s)", (rest,)) if kind == "pin" else GLib.Variant("(u)", (int(rest),)))
		elif verb == "cancel":
			if self.waiting:
				self.reply("org.bluez.Error.Canceled")
			if self.pairing:
				self.call(self.pairing, "org.bluez.Device1", "CancelPairing", None, None, self.ignore)

	def reply(self, error, value=None):
		kind, invocation = self.waiting
		self.waiting = None
		if error:
			invocation.return_dbus_error(error, "")
		else:
			invocation.return_value(value)

	def ignore(self, bus, result):
		try:
			bus.call_finish(result)
		except GLib.Error:
			pass

	def on_paired(self, bus, result):
		device = self.pairing
		self.pairing = None
		self.waiting = None
		try:
			bus.call_finish(result)
		except GLib.Error as e:
			name = Gio.DBusError.get_remote_error(e) or "org.bluez.Error.Failed"
			if not name.endswith("AlreadyExists"):
				emit("failed", error=name)
				return
		# Paired as Bloom leaves it on Windows: trusted, then connected.
		self.call(device, "org.freedesktop.DBus.Properties", "Set",
			GLib.Variant("(ssv)", ("org.bluez.Device1", "Trusted", GLib.Variant("b", True))), None, self.ignore)
		self.call(device, "org.bluez.Device1", "Connect", None, None, self.ignore)
		emit("paired")

	# ---- the agent ----

	def on_agent_call(self, bus, sender, path, interface, method, params, invocation):
		args = params.unpack()
		if method == "RequestConfirmation":
			self.waiting = ("confirm", invocation)
			emit("prompt", kind="confirm", pin="%06d" % args[1])
		elif method == "RequestPinCode":
			self.waiting = ("pin", invocation)
			emit("prompt", kind="provide")
		elif method == "RequestPasskey":
			self.waiting = ("passkey", invocation)
			emit("prompt", kind="provide")
		elif method == "DisplayPinCode":
			emit("prompt", kind="display", pin=args[1])
			invocation.return_value(None)
		elif method == "DisplayPasskey":
			emit("prompt", kind="display", pin="%06d" % args[1])
			invocation.return_value(None)
		elif method in ("RequestAuthorization", "AuthorizeService"):
			# The person already chose to pair: plain consent is given.
			invocation.return_value(None)
		elif method == "Cancel":
			self.waiting = None
			invocation.return_value(None)
		else:
			invocation.return_value(None)


def main():
	address = os.environ.get("BLOOM_BT_BUS")
	if address:
		bus = Gio.DBusConnection.new_for_address_sync(address,
			Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION, None, None)
	else:
		bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
	session = Session(bus)
	loop = GLib.MainLoop()
	try:
		session.start()
	except GLib.Error as e:
		emit("failed", error=Gio.DBusError.get_remote_error(e) or "org.bluez.Error.NotReady")
		return 1

	# Raw reads, split here: a buffered readline could hold back lines the
	# watch would never fire for again.
	pending = [b""]

	def on_input(fd, condition):
		data = os.read(fd, 4096) if condition & GLib.IOCondition.IN else b""
		if not data:
			loop.quit()
			return False
		pending[0] += data
		*lines, pending[0] = pending[0].split(b"\n")
		for line in lines:
			session.command(line.decode("utf-8", "replace"))
		return True

	GLib.io_add_watch(sys.stdin.fileno(), GLib.PRIORITY_DEFAULT, GLib.IOCondition.IN | GLib.IOCondition.HUP | GLib.IOCondition.ERR, on_input)
	loop.run()
	return 0


if __name__ == "__main__":
	sys.exit(main())
