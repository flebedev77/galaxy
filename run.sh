#!/bin/sh

odin build src -out:./main
if [ $? == 0 ]; then
  ./main
else
  echo "Error during compilation"
fi
