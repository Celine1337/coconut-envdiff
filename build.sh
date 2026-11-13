#!/usr/bin/env bash
# Build a launcher at bin/coconut-envdiff (Coconut is interpreted via coconut-run).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin
cat > bin/coconut-envdiff <<'WRAP'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/.local/bin:$PATH"
exec coconut-run "$DIR/src/main.coconut" "$@"
WRAP
chmod +x bin/coconut-envdiff
echo "built bin/coconut-envdiff"