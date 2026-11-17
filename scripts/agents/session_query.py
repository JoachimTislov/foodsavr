#!/usr/bin/env python3
"""Compatibility entry point for the agentctl session commands."""

import sys

from agentctl import main


if __name__ == "__main__":
    raise SystemExit(main(["sessions", *sys.argv[1:]]))
