#!/bin/bash
# Packages the application into build/ (uploaded as a pipeline artifact)
set -e
echo "=== Starting application build ==="
rm -rf build && mkdir -p build
cp -r app requirements.txt build/
cat > build/build-info.txt <<INFO
Application: Session 16 Calculator API
Build Status: SUCCESS
Commit: ${GITHUB_SHA:-local}
Run number: ${GITHUB_RUN_NUMBER:-local}
Build Date: $(date -u)
INFO
tar -czf calculator-build.tar.gz -C build .
mv calculator-build.tar.gz build/
ls -la build
echo "=== Build completed successfully ==="
