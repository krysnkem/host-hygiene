#!/bin/bash
# Opened by a CPU notification click: the CPU screen, with advice on what you could close.
exec "$(cd "$(dirname "$0")" && pwd -P)/host-hygiene.sh" focus perf cpu
