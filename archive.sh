#!/bin/bash

# Optional path argument, default to 'lib'
TARGET_DIR=${1:-lib}

# Output file
OUTPUT_FILE="archive.txt"

# Clear output file before writing
> "$OUTPUT_FILE"

# Find Dart files excluding generated ones, and append contents
find "$TARGET_DIR" \
  -name "*.dart" \
  -not -name "*.g.dart" \
  -not -name "*.freezed.dart" \
  -exec echo "=== {} ===" \; \
  -exec cat {} \; >> "$OUTPUT_FILE"

echo "Archive written to $OUTPUT_FILE"
