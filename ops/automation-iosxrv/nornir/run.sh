#!/usr/bin/env bash
# Shortcut for the show_version task. The generic runner is nr.sh.
#   bash run.sh                        -> show version | include Version (all nodes)
#   bash run.sh "show isis neighbors"  -> any show command (all nodes)
exec "$(cd "$(dirname "$0")" && pwd)/nr.sh" show_version.py "$@"
