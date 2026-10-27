#!/usr/bin/env python3
"""A throwaway StatusNotifierItem using the CI's existing PyGObject stack."""
from gi.repository import Gio, GLib

NAME = "org.kde.StatusNotifierItem-BloomTest-1"
PATH = "/StatusNotifierItem"
IFACE = "org.kde.StatusNotifierItem"
XML = """
<node>
  <interface name="org.kde.StatusNotifierItem">
    <method name="Activate"><arg direction="in" type="i" name="x"/><arg direction="in" type="i" name="y"/></method>
    <method name="SecondaryActivate"><arg direction="in" type="i" name="x"/><arg direction="in" type="i" name="y"/></method>
    <signal name="NewStatus"><arg type="s" name="status"/></signal>
    <property name="Id" type="s" access="read"/>
    <property name="Title" type="s" access="read"/>
    <property name="Status" type="s" access="read"/>
    <property name="Category" type="s" access="read"/>
    <property name="IconName" type="s" access="read"/>
    <property name="ItemIsMenu" type="b" access="read"/>
    <property name="Menu" type="o" access="read"/>
  </interface>
</node>
"""

conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
node = Gio.DBusNodeInfo.new_for_xml(XML)
status = "Active"


def prop(_conn, _sender, _path, _iface, key):
    values = {
        "Id": GLib.Variant("s", "org.example.BloomTest"),
        "Title": GLib.Variant("s", "Bloom Test Tray"),
        "Status": GLib.Variant("s", status),
        "Category": GLib.Variant("s", "ApplicationStatus"),
        "IconName": GLib.Variant("s", "applications-system"),
        "ItemIsMenu": GLib.Variant("b", False),
        "Menu": GLib.Variant("o", "/NO_DBUSMENU"),
    }
    return values[key]


def call(_conn, _sender, _path, _iface, method, _params, invocation):
    print("FAKE " + ("activated" if method == "Activate" else "secondary"), flush=True)
    invocation.return_value(None)


conn.register_object(PATH, node.interfaces[0], call, prop, None)
Gio.bus_own_name_on_connection(conn, NAME, Gio.BusNameOwnerFlags.NONE, None, None)


def make_passive():
    global status
    status = "Passive"
    conn.emit_signal(None, PATH, IFACE, "NewStatus", GLib.Variant("(s)", (status,)))
    return False


def register():
    try:
        conn.call_sync("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher",
                       "org.kde.StatusNotifierWatcher", "RegisterStatusNotifierItem",
                       GLib.Variant("(s)", (NAME,)), None, Gio.DBusCallFlags.NONE, 1000, None)
    except GLib.Error:
        return True
    GLib.timeout_add(1000, make_passive)
    return False


GLib.timeout_add(50, register)
GLib.MainLoop().run()
