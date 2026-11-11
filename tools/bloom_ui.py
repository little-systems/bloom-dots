"""How the installer talks: stages, one line per step, a plain summary, and a
question only when someone is at a terminal. Colour only on a terminal, never
under NO_COLOR."""
from __future__ import annotations

import os
import sys


class UI:
    def __init__(self, yes=False, stream=None):
        self.stream = stream or sys.stdout
        self.yes = yes
        self.interactive = sys.stdin.isatty() and self.stream.isatty()
        self.colour = self.stream.isatty() and "NO_COLOR" not in os.environ

    def _paint(self, code, text):
        return f"\033[{code}m{text}\033[0m" if self.colour else text

    def say(self, text=""):
        print(text, file=self.stream, flush=True)

    def title(self, text):
        self.say()
        self.say(self._paint("1", text))

    def stage(self, number, total, name, note=""):
        self.say()
        self.say(self._paint("1;36", f"[{number}/{total}] {name}") + (f"  {self._paint('2', note)}" if note else ""))

    def item(self, text):
        self.say(f"  • {text}")

    def step(self, label, ok=True, detail=""):
        mark = self._paint("32", "✓") if ok else self._paint("31", "✗")
        self.say(f"  {mark} {label}" + (f" — {detail}" if detail else ""))

    def note(self, text):
        self.say(f"  {self._paint('33', '!')} {text}")

    def confirm(self, question="Continue?"):
        if self.yes or not self.interactive:
            return True
        while True:
            answer = input(f"\n{question} [Y/n] ").strip().lower()
            if answer in ("", "y", "yes"):
                return True
            if answer in ("n", "no"):
                return False

    def menu(self, prompt, options):
        self.say()
        self.say(prompt)
        for number, option in enumerate(options, 1):
            self.say(f"  {number}) {option}")
        while True:
            answer = input(f"Choose 1-{len(options)}: ").strip()
            if answer.isdigit() and 1 <= int(answer) <= len(options):
                return int(answer) - 1
