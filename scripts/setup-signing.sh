#!/bin/bash
# Saves your Apple team ID in Config/Local.xcconfig so Xcode can sign the app for your iPhone.
# That file is ignored by git, so pulling new code never resets it.
#
# Usage:  scripts/setup-signing.sh            (finds your team ID automatically)
#         scripts/setup-signing.sh ABCDE12345 (uses the team ID you give it)
set -euo pipefail
cd "$(dirname "$0")/.."

team="${1:-}"
if [ -z "$team" ]; then
    # The "Apple Development" certificate Xcode made for you carries the team ID as OU=.
    team=$(security find-certificate -c "Apple Development" -p 2>/dev/null \
        | openssl x509 -noout -subject 2>/dev/null \
        | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -n 1 || true)
fi

if ! [[ "$team" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "Couldn't find your team ID automatically."
    echo "In Xcode: Settings… → Accounts → sign in with your Apple ID, build once with your team picked,"
    echo "then run this again. Or pass the ID yourself: scripts/setup-signing.sh ABCDE12345"
    exit 1
fi

cat > Config/Local.xcconfig <<CONFIG
// Made by scripts/setup-signing.sh. Not in git: this is your own Apple team.
DEVELOPMENT_TEAM = $team
CONFIG
echo "Saved team $team to Config/Local.xcconfig. Close and reopen the project in Xcode, then press Run."
