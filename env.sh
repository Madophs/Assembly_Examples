#!/bin/env bash
LD_LIBRARY_PATH="$(git rev-parse --show-toplevel)/build/lib:${LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH
