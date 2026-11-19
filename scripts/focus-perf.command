#!/bin/bash
# Opened by a memory/CPU notification click: the Memory screen, with advice on what you could close.
exec "$(cd "$(dirname "$0")" && pwd -P)/host-hygiene.sh" focus perf mem
