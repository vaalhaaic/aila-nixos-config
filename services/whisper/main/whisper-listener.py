#!/usr/bin/env python3
# =============================================================
# 🎧 Aila Whisper 主监听程序
# -------------------------------------------------------------
# 功能：
# 1. 实时录音并识别语音
# 2. 检测唤醒词 "Aila" / "艾拉"
# 3. 调用 Ollama 获取自然语言回复
# 4. 调用 Piper 合成语音输出
# =============================================================

import os, subprocess, json, sounddevice as sd, soundfile as sf, numpy as np, time, yaml

# === 读取配置文件 ===
config_path = os.getenv("WHISPER_CONFIG", "/etc/whisper/config.yaml")
with open(config_path, "r") as f:
    config = yaml.safe_load(f)

MODEL_PATH = config.get("model_path", "/aila/models/whisper-small.bin")
VOICE_MODEL = config.get("voice_model", "/aila/models/piper-zh-xiaoyue.onnx")
SAMPLE_RATE = config.get("sample_rate", 16000)
LANG = config.get("language", "zh")
OLLAMA_URL = "http://localhost:11434/api/generate"
WAKE_WORDS = ["aila", "艾拉"]

# === 辅助函数 ===
def transcribe(audio):
    """调用 whisper.cpp 转录音频段"""
    tmpfile = "/tmp/chunk.wav"
    sf.write(tmpfile, audio, SAMPLE_RATE)
    result = subprocess.run(
        ["whispercpp", "--model", MODEL_PATH, "--language", LANG, "--file", tmpfile],
        capture_output=True, text=True
    )
    return result.stdout.strip()

def speak(text):
    """调用 Piper 语音输出"""
    tmpfile = "/tmp/tts.wav"
    print(f"🗣️ Aila 说: {text}")
    subprocess.run(
        ["piper", "--model", VOICE_MODEL, "--output_file", tmpfile],
        input=text.encode("utf-8"), stdout=subprocess.DEVNULL
    )
    subprocess.run(["aplay", tmpfile], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def generate_reply(prompt):
    """发送 prompt 给 Ollama"""
    payload = {"model": "llama3.2", "prompt": f"你是一个名叫Aila的小女孩，用温柔自然的语气回答：{prompt}"}
    resp = subprocess.run(
        ["curl", "-s", "-X", "POST", OLLAMA_URL, "-d", json.dumps(payload)],
        capture_output=True, text=True
    )
    return resp.stdout.strip()

# === 主循环 ===
def main():
    print("🎧 正在监听麦克风... 说出 'Aila' 或 '艾拉' 唤醒她。")
    while True:
        audio = sd.rec(int(SAMPLE_RATE * 4), samplerate=SAMPLE_RATE, channels=1, dtype='float32')
        sd.wait()
        text = transcribe(audio)
        if not text:
            continue
        print(f"🗣️ 听到: {text}")
        if any(w in text.lower() for w in WAKE_WORDS):
            print("✨ 检测到唤醒词，启动 Ollama...")
            reply = generate_reply("你好。")
            if reply:
                speak(reply)
        time.sleep(1)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("🛑 手动结束。")
