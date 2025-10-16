
#!/usr/bin/env bash
# ============================================
# Aila 语音回路（Whisper HTTP + Ollama + Piper）
# 监听唤醒词 -> Whisper HTTP 转写 -> Ollama 推理 -> Piper 合成播报
# 依赖：arecord, curl, jq, ollama, piper, pw-cat/aplay
# ============================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/aila.conf"

if [[ -f /etc/aila/aila.conf ]]; then
  # shellcheck disable=SC1091
  source /etc/aila/aila.conf
elif [[ -f "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1091
  source "${CONFIG_FILE}"
fi

MIC_DEVICE=${MIC_DEVICE:-"plughw:2,0"}
WAKE_WORD=${WAKE_WORD:-"aila"}
WHISPER_HTTP_URL=${WHISPER_HTTP_URL:-"http://127.0.0.1:8080"}
OLLAMA_MODEL=${OLLAMA_MODEL:-"qwen2:7b"}
PIPER_MODEL_PATH=${PIPER_MODEL_PATH:-"/var/lib/aila/piper/zh_CN-huayan-low.onnx"}
PIPER_SPEAKER=${PIPER_SPEAKER:-0}
LOG_DIR=${LOG_DIR:-"/var/log/aila"}
TMP_DIR=${TMPDIR:-/tmp}

mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/aila-voice.log"

play_wav() {
  local wav="$1"
  if command -v pw-cat >/dev/null 2>&1; then
    pw-cat --play "${wav}" >/dev/null 2>&1 || true
  elif command -v aplay >/dev/null 2>&1; then
    aplay -q "${wav}" || true
  else
    echo "[WARN] 未找到 pw-cat 或 aplay" | tee -a "${LOG_FILE}"
  fi
}

record_chunk() {
  local secs="$1"
  local out
  out=$(mktemp "${TMP_DIR}/aila_audio_XXXX.wav")
  arecord -D "${MIC_DEVICE}" -r 16000 -c 1 -f S16_LE -d "${secs}" "${out}" >/dev/null 2>&1 || true
  echo "${out}"
}

transcribe_http() {
  local wav="$1"
  local endpoints=("/inference" "/transcribe" "/")
  local fields=("file" "audio" "audio_file")
  local text
  for ep in "${endpoints[@]}"; do
    for fld in "${fields[@]}"; do
      if out=$(curl -sS -X POST "${WHISPER_HTTP_URL}${ep}" -F "${fld}=@${wav}" 2>/dev/null); then
        text=$(echo "${out}" | jq -r 'if has("text") then .text else (.segments // [] | map(.text) | join(" ")) end' 2>/dev/null || true)
        if [[ -n "${text}" && "${text}" != "null" ]]; then
          echo "${text}"
          return 0
        fi
      fi
    done
  done
  return 1
}

speak_piper() {
  local text="$1"
  local wav
  wav=$(mktemp "${TMP_DIR}/aila_tts_XXXX.wav")
  if ! command -v piper >/dev/null 2>&1; then
    echo "[WARN] 缺少 piper，无法合成语音" | tee -a "${LOG_FILE}"
    rm -f "${wav}"
    return 1
  fi
  piper --model "${PIPER_MODEL_PATH}" --speaker "${PIPER_SPEAKER}" --output_file "${wav}" --text "${text}" >/dev/null 2>&1 || true
  play_wav "${wav}"
  rm -f "${wav}"
}

printf "Aila 语音回路已启动：唤醒词 '%s'，Whisper=%s，模型=%s
" "${WAKE_WORD}" "${WHISPER_HTTP_URL}" "${OLLAMA_MODEL}" | tee -a "${LOG_FILE}"

while true; do
  chunk=$(record_chunk 3)
  heard=$(transcribe_http "${chunk}" || echo "")
  rm -f "${chunk}"
  heard_lc=$(echo "${heard}" | tr '[:upper:]' '[:lower:]')
  if [[ -n "${heard_lc}" && "${heard_lc}" == *"${WAKE_WORD}"* ]]; then
    echo "[INFO] 检测到唤醒词，等待用户指令..." | tee -a "${LOG_FILE}"
    query_chunk=$(record_chunk 8)
    question=$(transcribe_http "${query_chunk}" || echo "")
    rm -f "${query_chunk}"
    if [[ -z "${question}" ]]; then
      echo "[WARN] 未识别到有效语音" | tee -a "${LOG_FILE}"
      continue
    fi
    echo "[用户] ${question}" | tee -a "${LOG_FILE}"

    if ! command -v ollama >/dev/null 2>&1; then
      echo "[WARN] 缺少 ollama，无法生成回答" | tee -a "${LOG_FILE}"
      continue
    fi
    reply=$(echo "${question}" | ollama run "${OLLAMA_MODEL}" 2>/dev/null | tail -n +2)
    reply=${reply:-"抱歉，我暂时无法回答。"}
    echo "[Aila] ${reply}" | tee -a "${LOG_FILE}"
    speak_piper "${reply}" || true
  fi
  sleep 1
done
