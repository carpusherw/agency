#!/usr/bin/env bash
#
# Print one random agent name: adjective-noun, matching the shape Claude Code
# already uses for session names. Swap the two lists if you would rather your
# agents had human names.

set -euo pipefail

ADJECTIVES=(amber brisk candid clever curious deft eager fluent frank keen
            lucid nimble patient quiet ready steady sunlit tidy vivid wry)
NOUNS=(anchor atlas beacon cedar compass ember harbor kestrel lantern ledger
       meridian orchard quarry ridge sable summit tempo thicket willow zenith)

a=${ADJECTIVES[$((RANDOM % ${#ADJECTIVES[@]}))]}
n=${NOUNS[$((RANDOM % ${#NOUNS[@]}))]}
printf '%s-%s\n' "$a" "$n"
