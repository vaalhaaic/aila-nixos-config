#!/usr/bin/env bash
# =============================================================
# 🎤 Piper 中文模型自动下载与测试脚本
# -------------------------------------------------------------
# 运行后自动下载 zh-xiaoyue 模型并播放测试语音。
# =============================================================

set -euo pipefail

# === 路径定义 ===
MODEL_DIR="/aila/models"
MODEL_FILE="${MODEL_DIR}/piper-zh-xiaoyue.onnx"
CONFIG_FILE="/etc/piper/config.yaml"
VOICE_NAME="zh-xiaoyue"
TEST_TEXT="你好，我是 Aila。欢迎回来。"

# === 1️⃣ 确保模型目录存在 ===
sudo mkdir -p "$MODEL_DIR"
sudo chown -R mason:mason "$MODEL_DIR"

# === 2️⃣ 检查模型是否已存在 ===
if [ -f "$MODEL_FILE" ]; then
  echo "✅ 模型已存在: $MODEL_FILE"
else
  echo "⬇️ 下载 Piper 中文女声模型（${VOICE_NAME}）..."
  wget -O "$MODEL_FILE" \
    "https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh_CN/${VOICE_NAME}/medium/${VOICE_NAME}.onnx" \
    || { echo "❌ 下载失败"; exit 1; }
  echo "✅ 模型下载完成: $MODEL_FILE"
fi

# === 3️⃣ 更新配置文件（如果存在）===
if [ -f "$CONFIG_FILE" ]; then
  echo "📝 更新配置文件..."
  sudo sed -i "s|^model_path:.*|model_path: ${MODEL_FILE}|" "$CONFIG_FILE" || true
else
  echo "⚙️ 创建默认配置文件: $CONFIG_FILE"
  sudo tee "$CONFIG_FILE" >/dev/null <<EOF
model_path: ${MODEL_FILE}
output_device: default
output_volume: 0.9
sample_rate: 22050
language: zh
voice_name: "自然女声-小悦"
EOF
fi

# === 4️⃣ 测试输出 ===
echo "🔊 测试语音输出..."
echo "$TEST_TEXT" | piper --model "$MODEL_FILE" --output_file /tmp/piper_test.wav
play -v 0.9 /tmp/piper_test.wav

echo "🎉 Piper 中文模型部署完成"
