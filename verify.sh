#!/usr/bin/env bash
# Preflight check for the BYOC lab (macOS).
#
# Usage, from the repository root, after `source ./env.sh`:
#     ./verify.sh                # checks the org alias byoc-org
#     ./verify.sh my-other-alias # checks a different alias
#
# Read-only: it changes nothing on your machine or in your org.

ORG_ALIAS="${1:-byoc-org}"
MIN_SF="2.130.9"
MIN_PLUGIN="0.1.5"
FAILS=0

pass() { printf '  [PASS] %s\n' "$1"; }
fail() { printf '  [FAIL] %s\n         -> %s\n' "$1" "$2"; FAILS=$((FAILS + 1)); }

# version_ge A B : true when A >= B (dotted numeric versions)
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -t. -k1,1n -k2,2n -k3,3n | head -n 1)" = "$2" ]; }

strip_ansi() { sed $'s/\033\\[[0-9;]*m//g'; }

echo "BYOC lab preflight (org alias: $ORG_ALIAS)"
echo

# 1. Salesforce CLI
if command -v sf >/dev/null 2>&1; then
  SF_VER="$(sf --version 2>/dev/null | strip_ansi | grep -oE '@salesforce/cli/[0-9]+\.[0-9]+\.[0-9]+' | cut -d/ -f3)"
  if [ -n "$SF_VER" ] && version_ge "$SF_VER" "$MIN_SF"; then
    pass "Salesforce CLI $SF_VER (>= $MIN_SF)"
  else
    fail "Salesforce CLI ${SF_VER:-unknown} (need >= $MIN_SF)" "Run: sf update   (docs/01-setup.md, Step 1)"
  fi
else
  fail "Salesforce CLI not found" "Install it (docs/01-setup.md, Step 1)"
fi

# 2. Code Extension plugin
PLUGIN_VER="$(sf plugins 2>/dev/null | strip_ansi | awk '$1 == "data-code-extension" {print $2}')"
if [ -n "$PLUGIN_VER" ] && version_ge "$PLUGIN_VER" "$MIN_PLUGIN"; then
  pass "Code Extension plugin $PLUGIN_VER (>= $MIN_PLUGIN)"
else
  fail "Code Extension plugin ${PLUGIN_VER:-not installed} (need >= $MIN_PLUGIN)" \
       "Run: sf plugins install @salesforce/plugin-data-code-extension   (docs/01-setup.md, Step 3)"
fi

# 3. Python 3.11 active (the plugin checks python3 first, then python)
PY_VER="$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
case "$PY_VER" in
  3.11.*) pass "python3 is $PY_VER ($(command -v python3))" ;;
  *) fail "python3 is ${PY_VER:-missing} (need exactly 3.11)" "Run: source ./env.sh   (docs/01-setup.md, Step 8)" ;;
esac

# 4. A virtual environment is active
if [ -n "${VIRTUAL_ENV:-}" ]; then
  pass "venv active: $VIRTUAL_ENV"
else
  fail "No venv active" "Run: source ./env.sh"
fi

# 5. pip inside the venv (the plugin runs 'python3 -m pip show')
if python3 -m pip --version >/dev/null 2>&1; then
  pass "pip available in the active Python"
else
  fail "pip missing from the active Python" "Run: uv pip install pip   (or recreate the venv with: uv venv --python 3.11 --seed .venv)"
fi

# 6. SDK installed
SDK_VER="$(python3 -m pip show salesforce-data-customcode 2>/dev/null | awk '/^Version:/ {print $2}')"
if [ -n "$SDK_VER" ]; then
  pass "salesforce-data-customcode $SDK_VER installed"
else
  fail "salesforce-data-customcode not installed in the active Python" "Run: uv pip install salesforce-data-customcode   (docs/01-setup.md, Step 6)"
fi

# 6b. pipreqs (scan calls it to detect imports for requirements.txt)
if command -v pipreqs >/dev/null 2>&1; then
  pass "pipreqs available (needed by 'script scan')"
else
  fail "pipreqs not found" "Run: uv pip install pipreqs   (or use 'script scan --no-requirements')"
fi

# 7. Java 17 on JAVA_HOME
if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
  J_VER="$("$JAVA_HOME/bin/java" -version 2>&1 | head -n 1 | grep -oE '"[0-9][^"]*"' | tr -d '"')"
  case "$J_VER" in
    17|17.*) pass "JAVA_HOME is Java $J_VER ($JAVA_HOME)" ;;
    *) fail "JAVA_HOME is Java ${J_VER:-unknown} (need 17)" "Run: source ./env.sh   (docs/01-setup.md, Step 7)" ;;
  esac
else
  fail "JAVA_HOME not set or not a JDK" "Run: source ./env.sh   (docs/01-setup.md, Steps 7-8)"
fi

# 8. Org alias authorized and connected
ORG_JSON="$(sf org display --target-org "$ORG_ALIAS" --json 2>/dev/null)"
if printf '%s' "$ORG_JSON" | grep -q '"connectedStatus": *"Connected"'; then
  pass "Org alias '$ORG_ALIAS' is connected"
else
  STATUS="$(printf '%s' "$ORG_JSON" | grep -oE '"connectedStatus": *"[^"]*"' | cut -d'"' -f4)"
  fail "Org alias '$ORG_ALIAS' is ${STATUS:-not authorized}" "Run: sf org login web --alias $ORG_ALIAS   (docs/02-authorize-org.md)"
fi

echo
if [ "$FAILS" -eq 0 ]; then
  echo "All checks passed. Continue with docs/03-run-locally.md."
  exit 0
fi
echo "$FAILS check(s) failed. Fix them and run ./verify.sh again."
exit 1
