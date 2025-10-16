#!/usr/bin/env python3
# =============================================================
# 🔊 Piper 语音合成服务
# -------------------------------------------------------------
# 接收文字输入（stdin 或 HTTP），调用 Piper 输出语音。
# =============================================================

import os, subprocess, sys, yaml

# === 读取配置 ===
with open("/etc/piper/config.yaml", "r") as f:
    config = yaml.safe_load(f)

MODEL = config.get("model_path", "/aila/models/piper-zh-xiaoyue.onnx")
OUTPUT_DEVICE = config.get("output_device", "default")
VOLUME = str(config.get("output_volume", 1.0))

def speak(text: str):
    print(f"🔈 正在播放: {text}")
    tmpfile = "/tmp/piper_tts.wav"
    subprocess.run(
        ["piper", "--model", MODEL, "--output_file", tmpfile],
        input=text.encode("utf-8"),
        stdout=subprocess.DEVNULL
    )
    subprocess.run(["play", "-v", VOLUME, tmpfile])

def main():
    print("🟢 Piper 已启动，等待文字输入（Ctrl+C 退出）")
    for line in sys.stdin:
        text = line.strip()
        if not text:
            continue
        speak(text)

if __name__ == "__main__":
    main()
