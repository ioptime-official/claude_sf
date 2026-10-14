#!/usr/bin/env bash
# detect-stacks.py must find stacks by content, never by hardcoded folder names.
cd "$(dirname "$0")/../.." || exit 1
script="$PWD/scripts/detect-stacks.py"
fail=0
ok()  { echo "PASS $1"; }
bad() { echo "FAIL $1"; fail=1; }
get() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
mkdir -p "$work/src/core/main" "$work/src/ext" "$work/web/shop" "$work/svc/Orders/src/Orders" "$work/svc/Orders/tests/Orders.Tests" "$work/wp/wp-content/plugins/promo"
cat > "$work/sfdx-project.json" <<'JSON'
{"packageDirectories":[{"path":"src/core","default":true},{"path":"src/ext"}],"sourceApiVersion":"62.0"}
JSON
echo '{"dependencies":{"react":"^18"}}' > "$work/web/shop/package.json"
echo '<Project Sdk="Microsoft.NET.Sdk.Web"/>' > "$work/svc/Orders/src/Orders/Orders.csproj"
echo '<Project Sdk="Microsoft.NET.Sdk"/>' > "$work/svc/Orders/tests/Orders.Tests/Orders.Tests.csproj"
printf '<?php\n/* Plugin Name: Promo */\n' > "$work/wp/wp-content/plugins/promo/promo.php"
mkdir -p "$work/node_modules/react-fake" && echo '{"dependencies":{"react":"1"}}' > "$work/node_modules/react-fake/package.json"

json="$(cd "$work" && python3 "$script")"
[ "$(echo "$json" | get 'd["salesforce"]["packageDirs"]')" = "['src/core', 'src/ext']" ] && ok "custom package directories" || bad "custom package directories"
[ "$(echo "$json" | get '[e["root"] for e in d["react"]]')" = "['web/shop']" ] && ok "react found, node_modules ignored" || bad "react found, node_modules ignored"
[ "$(echo "$json" | get '[e["root"] for e in d["dotnet"]]')" = "['svc/Orders']" ] && ok "dotnet service root" || bad "dotnet service root"
[ "$(echo "$json" | get 'd["dotnet"][0]["tests"]')" = "['svc/Orders/tests/Orders.Tests']" ] && ok "dotnet test project" || bad "dotnet test project"
[ "$(echo "$json" | get '[e["root"] for e in d["wordpress"]]')" = "['wp/wp-content/plugins/promo']" ] && ok "wordpress plugin by header" || bad "wordpress plugin by header"

# empty repo: no stacks, no crash
empty="$(mktemp -d)"; ej="$(cd "$empty" && python3 "$script")"
[ "$(echo "$ej" | get 'd["salesforce"]')" = "None" ] && ok "empty repo" || bad "empty repo"
rm -rf "$empty"

# this repo
self="$(python3 "$script")"
[ "$(echo "$self" | get 'd["salesforce"]["packageDirs"]')" = "['force-app']" ] && ok "this repo: salesforce" || bad "this repo: salesforce"
exit $fail
