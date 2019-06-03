#!/bin/bash

./build.sh -v p -d -wv "$@" 2>&1 |tee logs/build-p.log
