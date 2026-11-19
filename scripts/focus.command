#!/bin/bash
# Opened by a notification click (via open -a Terminal): start host-hygiene focused on freeing disk space.
exec "$(cd "$(dirname "$0")" && pwd -P)/host-hygiene.sh" focus
