#!/bin/bash
# Finds all .tr() and .trWith() calls in the lib/ directory and extracts the key.
# This is used to audit which keys are actually used in the code.

grep -rohE "'[^']+'\.tr(With)?\(" lib/ | sed -E "s/'(.*)'\.tr(With)?\(/\1/" | sort | uniq
grep -rohE "\"[^\"]+\"\.tr(With)?\(" lib/ | sed -E "s/\"(.*)\"\.tr(With)?\(/\1/" | sort | uniq
