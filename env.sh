# Project environment for the BYOC lab (macOS, zsh or bash).
#
# Usage, from the repository root. Source it; don't execute it:
#     source ./env.sh
#
# It activates the project's Python 3.11 venv, selects Java 17 for this
# terminal only, and points PySpark at the venv's Python. It changes nothing
# globally: open a new terminal and you are back to your normal defaults.

if [ -n "${ZSH_VERSION:-}" ]; then
  case "${ZSH_EVAL_CONTEXT:-}" in *file*) ;; *)
    echo "Run this with 'source ./env.sh' (not ./env.sh) so the settings stay in your terminal."; exit 1 ;;
  esac
  _byoc_root="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
  if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    echo "Run this with 'source ./env.sh' (not ./env.sh) so the settings stay in your terminal."; exit 1
  fi
  _byoc_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

_byoc_venv="$_byoc_root/patient-xml-transform/.venv"

if [ ! -f "$_byoc_venv/bin/activate" ]; then
  echo "No venv at $_byoc_venv"
  echo "Create it first (docs/01-setup.md, Step 5):"
  echo "    cd patient-xml-transform && uv venv --python 3.11 --seed .venv"
  unset _byoc_root _byoc_venv
  return 1
fi

# shellcheck disable=SC1091
source "$_byoc_venv/bin/activate"

if _byoc_java="$(/usr/libexec/java_home -v 17 -F 2>/dev/null)"; then
  export JAVA_HOME="$_byoc_java"
  export PATH="$JAVA_HOME/bin:$PATH"
else
  echo "WARNING: Java 17 not found. Install it with: brew install --cask zulu@17"
fi

export PYSPARK_PYTHON="$_byoc_venv/bin/python"

echo "Python : $(python3 --version 2>&1)  ($(command -v python3))"
echo "Java   : $(java -version 2>&1 | head -n 1)"
echo "Ready. Next: cd patient-xml-transform"

unset _byoc_root _byoc_venv _byoc_java
