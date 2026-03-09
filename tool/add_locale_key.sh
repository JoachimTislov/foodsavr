#!/bin/bash
# Adds multiple key-value pairs to all JSON files in assets/translations/
# Usage: ./tool/add_locale_key.sh "key1" "value1" "key2" "value2" ...

if [ "$#" -lt 2 ] || [ $(($# % 2)) -ne 0 ]; then
  echo "Usage: ./tool/add_locale_key.sh \"key1\" \"value1\" [\"key2\" \"value2\" ...]"
  exit 1
fi

for f in assets/translations/*.json; do
  echo "Processing $f..."
  
  # Create a temporary file for jq operations
  temp_file=$(mktemp)
  cp "$f" "$temp_file"

  # Iterate through arguments in pairs
  args=("$@")
  for ((i=0; i<${#args[@]}; i+=2)); do
    KEY="${args[i]}"
    VALUE="${args[i+1]}"
    echo "  Adding $KEY..."
    
    if command -v jq > /dev/null; then
      # jq's --arg safely handles the string input.
      # We use path() and setpath() to handle nested keys like "product.name"
      # split(".") converts "product.name" to ["product", "name"]
      jq --arg key "$KEY" --arg val "$VALUE" '
        setpath($key | split("."); $val)
      ' "$temp_file" > "$temp_file.tmp" && mv "$temp_file.tmp" "$temp_file"
    else
      echo "jq is not installed. Please install it to use this script."
      rm "$temp_file"
      exit 1
    fi
  done
  
  # Move the final result back to the original file
  mv "$temp_file" "$f"
done

echo "Done! Added $(($# / 2)) keys to all locale files."
