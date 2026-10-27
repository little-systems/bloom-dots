#!/usr/bin/env python3
"""A throwaway StatusNotifierItem for the isolated tray adapter test."""
import time
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
name = dbus.service.BusName("org.kde.StatusNotifierItem-BloomTest-1", bus)


class Item(dbus.service.Object):
    def __init__(self):
        super().__init__(bus, "/StatusNotifierItem")
        self.properties = {
            "Id": dbus.String("org.example.BloomTest"),
            "Title": dbus.String("Bloom Test Tray"),
            "Status": dbus.String("Active"),
            "Category": dbus.String("ApplicationStatus"),
            "IconName": dbus.String("applications-system"),
            "ItemIsMenu": dbus.Boolean(False),
            "Menu": dbus.ObjectPath("/NO_DBUSMENU"),
        }

    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        return self.properties if interface == "org.kde.StatusNotifierItem" else {}

    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="ss", out_signature="v")
    def Get(self, interface, key):
        if interface != "org.kde.StatusNotifierItem":
            raise dbus.exceptions.DBusException("unknown interface")
        return self.properties[key]

    @dbus.service.method("org.kde.StatusNotifierItem", in_signature="ii", out_signature="")
    def Activate(self, x, y):
        print("FAKE activated", flush=True)

    @dbus.service.method("org.kde.StatusNotifierItem", in_signature="ii", out_signature="")
    def SecondaryActivate(self, x, y):
        print("FAKE secondary", flush=True)

    @dbus.service.signal("org.kde.StatusNotifierItem", signature="s")
    def NewStatus(self, status):
        pass

    def make_passive(self):
        self.properties["Status"] = dbus.String("Passive")
        self.NewStatus("Passive")
        return False


item = Item()
for _ in range(100):
    if bus.name_has_owner("org.kde.StatusNotifierWatcher"):
        watcher = bus.get_object("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher")
        dbus.Interface(watcher, "org.kde.StatusNotifierWatcher").RegisterStatusNotifierItem(name.get_name())
        break
    time.sleep(0.05)
else:
    raise SystemExit("watcher unavailable")

GLib.timeout_add(1000, item.make_passive)
GLib.MainLoop().run()
