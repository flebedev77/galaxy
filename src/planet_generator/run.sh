#!/bin/sh

set -xe
odin build . -out:./main
./main
