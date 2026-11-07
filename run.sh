#!/usr/bin/env bash
set -e
./compile.sh
if [ -n "$1" ]; then
  java -cp out com.lil.miniscript.MiniScript "$1"
else
  java -cp out com.lil.miniscript.MiniScript
fi
