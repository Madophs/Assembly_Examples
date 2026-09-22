#!/bin/env bash
LD_LIBRARY_PATH="$(git rev-parse --show-toplevel)/build/lib"
export LD_LIBRARY_PATH
