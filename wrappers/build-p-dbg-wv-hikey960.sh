#!/bin/bash

./build.sh -v p -d -wv -t hikey960 "$@" 2>&1 |tee logs/build-p.log
