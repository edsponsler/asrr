#!/bin/bash
#
# This script loads environment variables from the asrr_agent/.env file
# for local development. It is designed to be sourced from your shell,
# not executed directly. This allows it to modify the environment of your
# current terminal session.
#
# Usage (from the project root directory):
#   source load-env.sh
#

ENV_FILE="asrr_agent/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file not found at ${ENV_FILE}" >&2
    echo "Please ensure you are running this script from the project root directory." >&2
    return 1 # Use 'return' for sourced scripts to avoid exiting the shell
fi

echo "Loading and exporting variables from ${ENV_FILE}:"

while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^\s*# ]] || [[ -z "$line" ]] && continue

    # Export the variable and print it to the console
    export "$line"
    echo "  - ${line}"
done < "$ENV_FILE"

echo "Environment variables loaded."