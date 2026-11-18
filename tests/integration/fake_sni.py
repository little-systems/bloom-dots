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

MENU_PATH = "/Menu"
MENU_XML = """
<node>
  <interface name="com.canonical.dbusmenu">
    <method name="GetLayout"><arg direction="in" type="i"/><arg direction="in" type="i"/><arg direction="in" type="as"/>
      <arg direction="out" type="u"/><arg direction="out" type="(ia{sv}av)"/></method>
    <method name="GetGroupProperties"><arg direction="in" type="ai"/><arg direction="in" type="as"/><arg direction="out" type="a(ia{sv})"/></method>
    <method name="GetProperty"><arg direction="in" type="i"/><arg direction="in" type="s"/><arg direction="out" type="v"/></method>
    <method name="Event"><arg direction="in" type="i"/><arg direction="in" type="s"/><arg direction="in" type="v"/><arg direction="in" type="u"/></method>
    <method name="EventGroup"><arg direction="in" type="a(isvu)"/><arg direction="out" type="ai"/></method>
    <method name="AboutToShow"><arg direction="in" type="i"/><arg direction="out" type="b"/></method>
    <method name="AboutToShowGroup"><arg direction="in" type="ai"/><arg direction="out" type="ai"/><arg direction="out" type="ai"/></method>
    <signal name="LayoutUpdated"><arg type="u"/><arg type="i"/></signal>
    <property name="Version" type="u" access="read"/>
    <property name="TextDirection" type="s" access="read"/>
    <property name="Status" type="s" access="read"/>
    <property name="IconThemePath" type="as" access="read"/>
  </interface>
</node>
"""
ENTRIES = [(1, {"label": GLib.Variant("s", "Show")}), (2, {"type": GLib.Variant("s", "separator")}),
           (3, {"label": GLib.Variant("s", "Paused"), "enabled": GLib.Variant("b", False)})]


def menu_call(_conn, _sender, _path, _iface, method, params, invocation):
    if method == "GetLayout":
        children = [GLib.Variant("(ia{sv}av)", (i, props, [])) for i, props in ENTRIES]
        root = (0, {"children-display": GLib.Variant("s", "submenu")}, children)
        invocation.return_value(GLib.Variant("(u(ia{sv}av))", (1, root)))
    elif method == "GetGroupProperties":
        invocation.return_value(GLib.Variant("(a(ia{sv}))", ([(i, p) for i, p in ENTRIES if i in params[0]],)))
    elif method == "GetProperty":
        invocation.return_value(GLib.Variant("(v)", (GLib.Variant("s", ""),)))
    elif method == "Event":
        print(f"FAKE menu {params[1]} {params[0]}", flush=True)
        invocation.return_value(None)
    elif method == "EventGroup":
        for event in params[0]:
            print(f"FAKE menu {event[1]} {event[0]}", flush=True)
        invocation.return_value(GLib.Variant("(ai)", ([],)))
    elif method == "AboutToShow":
        invocation.return_value(GLib.Variant("(b)", (False,)))
    else:
        invocation.return_value(GLib.Variant("(aiai)", ([], [])))


def menu_prop(_conn, _sender, _path, _iface, key):
    return {"Version": GLib.Variant("u", 3), "TextDirection": GLib.Variant("s", "ltr"),
            "Status": GLib.Variant("s", "normal"), "IconThemePath": GLib.Variant("as", [])}[key]


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
        "Menu": GLib.Variant("o", MENU_PATH),
    }
    return values[key]


def call(_conn, _sender, _path, _iface, method, _params, invocation):
    print("FAKE " + ("activated" if method == "Activate" else "secondary"), flush=True)
    invocation.return_value(None)


conn.register_object(PATH, node.interfaces[0], call, prop, None)
conn.register_object(MENU_PATH, Gio.DBusNodeInfo.new_for_xml(MENU_XML).interfaces[0], menu_call, menu_prop, None)
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
    GLib.timeout_add(3000, make_passive)
    return False


GLib.timeout_add(50, register)
GLib.MainLoop().run()
