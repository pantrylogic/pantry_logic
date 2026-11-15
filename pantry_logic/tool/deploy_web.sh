#!/usr/bin/env bash
# Build the web app and mirror it into ../docs (GitHub Pages serves main:/docs).
# Usage (from pantry_logic/): bash tool/deploy_web.sh
# Then commit docs/ and pantry_logic/build/web (git add -u pantry_logic/build/web)
# and push main.
set -euo pipefail
cd "$(dirname "$0")/.."

# The temporary viewport debug overlay must never ship.
if grep -q "DEBUG-OVERLAY" web/index.html; then
  echo "web/index.html still contains the DEBUG-OVERLAY block; remove it before deploying." >&2
  exit 1
fi

# MSYS_NO_PATHCONV stops Git Bash rewriting /pantry_logic/ into a Windows path.
MSYS_NO_PATHCONV=1 flutter build web --release --base-href /pantry_logic/

# flutter build web can print "Built" yet leave a partial build/web (seen after
# git rewrote the tracked copy). Refuse to mirror unless everything is there.
missing=0
while IFS= read -r f; do
  [ -e "build/web/$f" ] || { echo "missing in build/web: $f"; missing=1; }
done < <(cd web && find . -type f ! -name '.*' | sed 's|^\./||')
for f in main.dart.js flutter.js flutter_service_worker.js \
         assets/AssetManifest.bin.json assets/FontManifest.json; do
  [ -e "build/web/$f" ] || { echo "missing in build/web: $f"; missing=1; }
done
if [ "$missing" != 0 ]; then
  echo "Partial web build; not mirroring. Run this script again." >&2
  exit 1
fi

# The family beta guide lives at docs/guide/ (served at /pantry_logic/guide/).
# The mirror below only adds/overwrites files, so it survives, but refuse to
# deploy if it has gone missing so nobody ships a deploy that drops the guide.
if [ ! -f ../docs/guide/index.html ]; then
  echo "docs/guide/index.html is missing; restore the family guide before deploying." >&2
  exit 1
fi

cp -r build/web/. ../docs/

if [ ! -f ../docs/guide/index.html ]; then
  echo "docs/guide/ was removed during the mirror; aborting." >&2
  exit 1
fi

# Serve docs/ as-is, without Jekyll. Flutter doesn't copy dotfiles from web/,
# so the marker is (re)created here on every deploy.
touch ../docs/.nojekyll

echo "Mirrored build/web into docs/ ($(find build/web -type f | wc -l) files) + .nojekyll"
