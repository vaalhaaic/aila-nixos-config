#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/etc/whisper/config.yaml"
VOICE_MODEL=$(grep '^voice_model:' $CONFIG_FILE | awk '{print $2}')
TEXT="${1:-你好，我是Aila。}"
TMP_WAV="/tmp/piper_tts.wav"

echo "🗣️ 使用 Piper 合成语音..."
echo "$TEXT" | piper --model "$VOICE_MODEL" --output_file "$TMP_WAV" >/dev/null

echo "🔈 播放音频..."
aplay "$TMP_WAV"