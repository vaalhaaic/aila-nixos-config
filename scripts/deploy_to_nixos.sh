#!/usr/bin/env bash
# 一键部署占位脚本
set -euo pipefail

echo "TODO: 实现部署逻辑 (nixos-rebuild switch)"


set -e
echo "🚀 Deploying Aila mappings..."

MAP_FILE="deploy/mapping.yaml"
python3 - <<'PY'
import yaml, os, subprocess
with open("deploy/mapping.yaml") as f:
    cfg = yaml.safe_load(f)
for m in cfg["mappings"]:
    print(f"🔁 {m['name']}: {m['src']} → {m['dst']}")
    cmd = ["sudo", "rsync", "-av", "--delete", m["src"], m["dst"]]
    subprocess.run(cmd, check=True)
PY