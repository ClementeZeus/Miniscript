#!/usr/bin/env bash
set -e
mkdir -p out
javac -d out $(find src -name "*.java")
echo "Compiled to ./out"
