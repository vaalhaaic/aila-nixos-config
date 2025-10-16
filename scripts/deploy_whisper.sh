#!/usr/bin/env bash
set -euo pipefail

WORKDIR=/opt/whisper
MODEL_URL=https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin

echo "🧱 初始化环境..."
sudo mkdir -p $WORKDIR
cd $WORKDIR

echo "📦 拉取 whisper.cpp 源码..."
if [ ! -d whisper.cpp ]; then
  sudo git clone https://github.com/ggerganov/whisper.cpp.git
fi
cd whisper.cpp

echo "🛠️ 构建 CUDA 版本..."
sudo nix-shell -p git cmake cudaPackages.cudatoolkit --run "cmake -DWITH_CUDA=ON . && make -j$(nproc)"

echo "🎧 下载模型..."
mkdir -p models
[ -f models/ggml-base.bin ] || wget -O models/ggml-base.bin $MODEL_URL

echo "⚙️ 注册 systemd 服务..."
sudo tee /etc/systemd/system/whisper.service > /dev/null <<'EOF'
[Unit]
Description=Whisper.cpp local speech-to-text service
After=network.target sound.target

[Service]
ExecStart=/opt/whisper/whisper.cpp/server -m /opt/whisper/whisper.cpp/models/ggml-base.bin -t 6 -p 8080
WorkingDirectory=/opt/whisper/whisper.cpp
Restart=always
User=mason

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now whisper.service
echo "✅ Whisper 服务已启动：http://localhost:8080"
