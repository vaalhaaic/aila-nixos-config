#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/etc/whisper/config.yaml"
MODEL_PATH=$(grep '^model_path:' $CONFIG_FILE | awk '{print $2}')
OUT_DIR=$(grep '^output_dir:' $CONFIG_FILE | awk '{print $2}')
LANG=$(grep '^language:' $CONFIG_FILE | awk '{print $2}')

mkdir -p "$OUT_DIR"
TMP_WAV="$OUT_DIR/record_$(date +%Y-%m-%d_%H-%M-%S).wav"
TXT_OUT="${TMP_WAV%.wav}.txt"

echo "🎤 正在录音 (10 秒)..."
ffmpeg -f alsa -i default -ar 16000 -ac 1 -t 10 "$TMP_WAV" -y

echo "🧠 开始识别..."
whispercpp --model "$MODEL_PATH" --language "$LANG" --file "$TMP_WAV" > "$TXT_OUT"

echo "✅ 转写完成：$TXT_OUT"
cat "$TXT_OUT"
