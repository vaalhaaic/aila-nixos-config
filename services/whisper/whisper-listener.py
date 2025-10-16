#!/usr/bin/env python3
import os, time, subprocess, json, sounddevice as sd, numpy as np

WAKE_WORD = "aila"
SAMPLE_RATE = 16000
BLOCK_DURATION = 3  # 秒

MODEL_PATH = "/aila/models/whisper-small.bin"
OLLAMA_URL = "http://localhost:11434/api/generate"
TTS_SCRIPT = "/usr/local/bin/tts-speak.sh"  # 待写

def transcribe_chunk(audio):
    """调用 whisper.cpp 转录音频段"""
    tmpfile = "/tmp/chunk.wav"
    import soundfile as sf
    sf.write(tmpfile, audio, SAMPLE_RATE)
    result = subprocess.run(
        ["whispercpp", "--model", MODEL_PATH, "--file", tmpfile, "--language", "zh"],
        capture_output=True, text=True
    )
    return result.stdout.strip()

def send_to_ollama(prompt):
    """发送到 Ollama 并返回回复"""
    payload = {"model": "llama3.2", "prompt": f"你是一个名叫Aila的小女孩，请自然地回答：{prompt}"}
    resp = subprocess.run(
        ["curl", "-s", "-X", "POST", OLLAMA_URL, "-d", json.dumps(payload)],
        capture_output=True, text=True
    )
    return resp.stdout

def main():
    print("🎧 正在监听麦克风（说出“艾拉”唤醒）...")
    while True:
        audio = sd.rec(int(SAMPLE_RATE * BLOCK_DURATION), samplerate=SAMPLE_RATE, channels=1, dtype='float32')
        sd.wait()
        text = transcribe_chunk(audio)
        if not text:
            continue
        print("🗣️ 听到:", text)
        if WAKE_WORD in text.lower() or "艾拉" in text:
            print("✨ 检测到唤醒词，启动 Ollama 生成...")
            reply = send_to_ollama("你好，Aila。")
            print("💬 回复:", reply)
            subprocess.run([TTS_SCRIPT, reply])
        time.sleep(0.5)

if __name__ == "__main__":
    main()
