#!/usr/bin/env bash
# 用 Piper 播放一句话
text="$*"
[ -z "$text" ] && text="你好，我是 Aila。"
echo "$text" | /run/current-system/sw/bin/bash -lc "cd /opt/aila/piper && nix develop --command python3 main/piper-server.py"