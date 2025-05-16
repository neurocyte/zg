#!/bin/sh

if ! zig build -Doptimize=ReleaseSafe; then
  exit 1
fi

cd zig-out/bin/

echo "\nBinary sizes ======="
ls -lh | awk '{ print $5, $9 }'

echo "\nBenchmarks ==========\n"
for bin in *; do ./$bin ../../data/lang_mix.txt; done

cd - > /dev/null
