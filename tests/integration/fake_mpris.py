#!/usr/bin/env python3
"""A minimal MPRIS player on the session bus for integration tests.

Usage: fake_mpris.py NAME [--playing] [--title T] [--artist A] [--length-s N]
Records every method call (PlayPause, Next, Previous, SetPosition, Seek) on
stdout as "CALL <name> <args>" so tests can assert on them.
"""
import argparse, sys
from gi.repository import Gio, GLib

XML = """
<node>
  <interface name="org.mpris.MediaPlayer2">
    <method name="Raise"/><method name="Quit"/>
    <property name="CanQuit" type="b" access="read"/><property name="CanRaise" type="b" access="read"/>
    <property name="HasTrackList" type="b" access="read"/><property name="Identity" type="s" access="read"/>
    <property name="SupportedUriSchemes" type="as" access="read"/><property name="SupportedMimeTypes" type="as" access="read"/>
  </interface>
  <interface name="org.mpris.MediaPlayer2.Player">
    <method name="Next"/><method name="Previous"/><method name="Pause"/><method name="PlayPause"/>
    <method name="Stop"/><method name="Play"/>
    <method name="Seek"><arg direction="in" type="x" name="Offset"/></method>
    <method name="SetPosition"><arg direction="in" type="o" name="TrackId"/><arg direction="in" type="x" name="Position"/></method>
    <method name="OpenUri"><arg direction="in" type="s" name="Uri"/></method>
    <signal name="Seeked"><arg type="x" name="Position"/></signal>
    <property name="PlaybackStatus" type="s" access="read"/><property name="Rate" type="d" access="readwrite"/>
    <property name="Metadata" type="a{sv}" access="read"/><property name="Volume" type="d" access="readwrite"/>
    <property name="Position" type="x" access="read"/><property name="MinimumRate" type="d" access="read"/>
    <property name="MaximumRate" type="d" access="read"/><property name="CanGoNext" type="b" access="read"/>
    <property name="CanGoPrevious" type="b" access="read"/><property name="CanPlay" type="b" access="read"/>
    <property name="CanPause" type="b" access="read"/><property name="CanSeek" type="b" access="read"/>
    <property name="CanControl" type="b" access="read"/>
  </interface>
</node>
"""

p = argparse.ArgumentParser()
p.add_argument("name")
p.add_argument("--playing", action="store_true")
p.add_argument("--title", default="Fake Song")
p.add_argument("--artist", default="Fake Artist")
p.add_argument("--length-s", type=int, default=200)
a = p.parse_args()

state = {"playing": a.playing, "title": a.title, "position": 0}
TRACK = "/org/bloom/fake/track/1"
node = Gio.DBusNodeInfo.new_for_xml(XML)
conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)

def metadata():
    return GLib.Variant("a{sv}", {
        "mpris:trackid": GLib.Variant("o", TRACK),
        "mpris:length": GLib.Variant("x", a.length_s * 1_000_000),
        "xesam:title": GLib.Variant("s", state["title"]),
        "xesam:artist": GLib.Variant("as", [a.artist]),
    })

def props(iface):
    if iface == "org.mpris.MediaPlayer2":
        return {"CanQuit": GLib.Variant("b", False), "CanRaise": GLib.Variant("b", False),
                "HasTrackList": GLib.Variant("b", False), "Identity": GLib.Variant("s", a.name),
                "SupportedUriSchemes": GLib.Variant("as", []), "SupportedMimeTypes": GLib.Variant("as", [])}
    return {"PlaybackStatus": GLib.Variant("s", "Playing" if state["playing"] else "Paused"),
            "Rate": GLib.Variant("d", 1.0), "Metadata": metadata(), "Volume": GLib.Variant("d", 1.0),
            "Position": GLib.Variant("x", state["position"]), "MinimumRate": GLib.Variant("d", 1.0),
            "MaximumRate": GLib.Variant("d", 1.0), "CanGoNext": GLib.Variant("b", True),
            "CanGoPrevious": GLib.Variant("b", True), "CanPlay": GLib.Variant("b", True),
            "CanPause": GLib.Variant("b", True), "CanSeek": GLib.Variant("b", True),
            "CanControl": GLib.Variant("b", True)}

def changed(names):
    p = props("org.mpris.MediaPlayer2.Player")
    conn.emit_signal(None, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "PropertiesChanged",
                     GLib.Variant("(sa{sv}as)", ("org.mpris.MediaPlayer2.Player", {n: p[n] for n in names}, [])))

def call(_c, _s, _o, iface, method, params, inv):
    print("CALL", method, params.unpack() if params else "", flush=True)
    if method in ("PlayPause", "Play", "Pause", "Stop"):
        state["playing"] = {"PlayPause": not state["playing"], "Play": True}.get(method, False)
        changed(["PlaybackStatus"])
    elif method in ("Next", "Previous"):
        state["title"] = f"{a.title} ({method})"; state["position"] = 0; changed(["Metadata"])
    elif method == "SetPosition":
        state["position"] = params.unpack()[1]
        conn.emit_signal(None, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Seeked",
                         GLib.Variant("(x)", (state["position"],)))
    inv.return_value(None)

def get_prop(_c, _s, _o, iface, name):
    return props(iface)[name]

def set_prop(*_):
    return True

for iface in node.interfaces:
    conn.register_object("/org/mpris/MediaPlayer2", iface, call, get_prop, set_prop)
Gio.bus_own_name_on_connection(conn, f"org.mpris.MediaPlayer2.{a.name}", Gio.BusNameOwnerFlags.NONE, None, None)
print("READY", flush=True)
GLib.MainLoop().run()
