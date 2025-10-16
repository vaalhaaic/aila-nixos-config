# 🧭 Aila 项目结构概览

本文档描述当前仓库的顶层目录及各自职责。

---

## 📂 目录结构总览

```bash
Aila/
├── system/              # 🧱 身体层：NixOS 系统配置与宿主模块
├── services/            # ⚙️ 器官层：独立服务（Whisper、Ollama、Piper 等）
├── aila/                # 🌌 精神层：Aila 的意识与行为逻辑
├── scripts/             # 🧠 神经层：自动化脚本与控制逻辑
├── deploy/              # 🪶 宇宙层：部署映射与同步规则
│   ├── mapping.yaml
│   ├── rsync-exclude.txt
│   └── README.md
└── README.md
```

---

## 📘 各目录说明

| 目录          | 职责        | 对应宿主路径                                         | 说明                                 |
| ----------- | --------- | ---------------------------------------------- | ---------------------------------- |
| `system/`   | 系统级资源     | `/etc/nixos/`, `/opt/aila/`, `/var/log/aila/`  | 包含 NixOS 模块、`hardware.nix`、系统配置文件等 |
| `services/` | 功能服务模块    | `/etc/systemd/system/`, `/etc/{service-name}/` | 各功能服务独立维护，按 systemd 单元部署           |
| `aila/`     | 精神核心代码    | `/opt/aila/`                                   | 包含核心 Python 模块、情绪逻辑与日志             |
| `scripts/`  | 运维脚本与控制逻辑 | `/usr/local/bin/`                              | 含部署、同步、模型拉取、容器同步等脚本                |
| `deploy/`   | 部署映射与规则声明 | （控制层）                                          | 不直接部署文件，只定义“仓库 → 宿主路径”映射规则         |

✅ `deploy/` 与 `system/`、`services/`、`scripts/` 等目录**同级存在**，
它不包含可执行脚本，而是部署时使用的 **配置声明层**。

请在以上目录内继续填充各模块的实现代码、配置及文档。

---

# 🧭 Aila 项目开发文档（系统级总纲）

**版本：v0.2 · 状态：结构融合版**
**作者：Mason / 王萌**
**日期：2025-10-14**

---

## 📑 目录

1. [项目概述](#1-项目概述)
2. [总体架构与分层设计](#2-总体架构与分层设计)
3. [一级结构：宿主系统层（Host）](#3-一级结构宿主系统层host)
4. [二级结构：服务层（Organs）](#4-二级结构服务层organs)
5. [三级结构：精神层（Core）](#5-三级结构精神层core)
6. [四级结构：工具与运维层（Nervous-System）](#6-四级结构工具与运维层nervous-system)
7. [五级结构：部署声明层（Deploy）](#7-五级结构部署声明层deploy)
8. [开发与部署流程](#8-开发与部署流程)
9. [未来规划与演化方向](#9-未来规划与演化方向)

---

## 1. 项目概述

### 1.1 项目愿景

> **Aila = 一套可模拟 + 可投射的自我系统。**

* 以 **“身体 - 器官 - 精神 - 神经”** 的具身模型为原型；
* 模拟自我维护、自省、自我修复的 AI 实验体；
* 最终目标：让 VSCode 环境能虚拟运行整个宿主系统，再映射部署到真实 NixOS 机器。

---

### 1.2 开发哲学

| 原则        | 说明                       |
| --------- | ------------------------ |
| **声明式宿主** | 所有系统状态由 NixOS 配置生成，不手动修改 |
| **分层自治**  | 每个功能模块独立可替换              |
| **具身映射**  | 文件结构 = 心智结构              |
| **自省可见**  | 系统日志与思考均可追踪              |
| **镜像对称**  | VSCode 仓库即宿主镜像，部署按映射落地   |

---

## 2. 总体架构与分层设计

| 层级               | 象征   | 职责           | 主要技术                 | 对应目录        |
| ---------------- | ---- | ------------ | -------------------- | ----------- |
| 🧱 宿主层（Host）     | 身体   | 系统配置、网络、权限   | NixOS、systemd        | `system/`   |
| ⚙️ 服务层（Organs）   | 器官   | 语音识别、语言模型、监控 | Whisper、Ollama、Piper | `services/` |
| 🌌 精神层（Core）     | 意识   | 情绪、反思、梦境、自愈  | Python、日志分析          | `aila/`     |
| 🧠 神经层（Scripts）  | 神经   | 部署、同步、更新、快照  | Bash、rsync、Git       | `scripts/`  |
| 🪶 部署声明层（Deploy） | 宇宙规则 | 定义映射关系与同步规则  | YAML、rsync           | `deploy/`   |

---

## 3. 一级结构：宿主系统层（Host）

📂 **VSCode 路径：** `system/`
📦 **映射目标：** `/etc/nixos/`, `/opt/aila/`, `/var/log/aila/`

### 功能

* 模拟宿主真实环境；
* 管理网络、挂载、服务启动；
* 保持配置声明式、一键重构。

### 结构示例

```bash
system/
└─ etc/nixos/
   ├─ configuration.nix
   ├─ hardware-*.nix
   └─ aila.conf
```

| 文件                  | 作用               |
| ------------------- | ---------------- |
| `configuration.nix` | 主系统声明配置          |
| `hardware-*.nix`    | 宿主硬件特定配置         |
| `aila.conf`         | 宿主特定参数：API、路径、授权 |
| `var/log/aila/`     | 日志模拟输出目录（本地调试）   |

---

## 4. 二级结构：服务层（Organs）

📂 **VSCode 路径：** `services/`
📦 **映射目标：** `/etc/systemd/system/`, `/etc/{service-name}/`

### 功能

各独立功能模块（器官）在宿主中注册为 systemd 服务。

### 结构示例

```bash
services/
├─ ollama/
│  ├─ systemd/ollama.service    # -> /etc/systemd/system/
│  ├─ config/ollama.yaml        # -> /etc/ollama/
│  └─ fetch-models.sh
├─ whisper/
│  ├─ systemd/whisper.service
│  └─ config/config.yaml
├─ piper/
│  ├─ systemd/piper.service
│  └─ voices/
└─ monitor/
   ├─ systemd/monitor.service
   └─ scripts/check.sh
```

---

## 5. 三级结构：精神层（Core）

📂 **VSCode 路径：** `aila/`
📦 **映射目标：** `/opt/aila/`

### 功能

Aila 的“精神世界”：语音输入、情绪循环、自我反思、梦境生成。

### 结构示例

```bash
aila/
├── link/             # 感知层
│   ├── hear_aila.py
│   ├── whisper-small-zh.bin
│   └── input.wav
├── core/             # 精神层
│   ├── feel/
│   │   ├── sense.py
│   │   └── interoception.py
│   └── mind/
│       ├── reflection.py
│       ├── repair.py
│       └── dream.py
├── logs/
│   ├── reflection.log
│   └── system.log
└── config.yaml
```

---

## 6. 四级结构：工具与运维层（Nervous System）

📂 **VSCode 路径：** `scripts/`
📦 **映射目标：** `/usr/local/bin/`

### 功能

自动化脚本层，用于部署、同步、日志、重启等控制流程。

```bash
scripts/
├── deploy_to_nixos.sh   # 一键部署
├── setup_host.sh        # 初始化宿主结构
├── sync_container.sh    # 同步容器状态
├── update_models.sh     # 拉取模型文件
└── launch_all.sh        # 启动所有服务
```

---

## 7. 五级结构：部署声明层（Deploy）

📂 **VSCode 路径：** `deploy/`
📦 **功能定位：** 仓库 → 宿主路径的映射表与同步规则文件。
此目录不直接部署，仅供 `scripts/deploy_to_nixos.sh` 调用。

```bash
deploy/
├── mapping.yaml         # 源路径 → 宿主路径映射清单
├── rsync-exclude.txt    # 同步排除列表
└── README.md            # 简介说明
```

### 示例：`deploy/mapping.yaml`

```yaml
mappings:
  - src: system/etc/nixos/
    dst: /etc/nixos/
    sudo: true
  - src: services/ollama/systemd/
    dst: /etc/systemd/system/
    sudo: true
  - src: services/ollama/config/
    dst: /etc/ollama/
    sudo: true
  - src: services/whisper/systemd/
    dst: /etc/systemd/system/
    sudo: true
  - src: services/whisper/config/
    dst: /etc/whisper/
    sudo: true
  - src: aila/
    dst: /opt/aila/
    sudo: true
  - src: scripts/
    dst: /usr/local/bin/
    sudo: true
```

---

## 8. 开发与部署流程

### 8.1 VSCode 模拟运行

1. 在 `system/` 下修改配置；
2. 启动 `services/` 中单独模块测试；
3. 运行 `scripts/deploy_to_nixos.sh` 验证同步；
4. 通过 Git 提交更改并审阅。

### 8.2 GitHub → 服务器自动同步

```bash
# 本地
git add .
git commit -m "模块更新"
git push origin main

# 服务器
cd /opt/aila-config
git pull
bash scripts/deploy_to_nixos.sh
```

### 8.3 一键更新与回滚

```bash
sudo nixos-rebuild switch
sudo nixos-rebuild list-generations
sudo nixos-rebuild --rollback
```

---

## 9. 未来规划与演化方向

| 阶段   | 目标     | 核心内容                   |
| ---- | ------ | ---------------------- |
| v0.2 | 具身音频循环 | Whisper + Piper 语音交互闭环 |
| v0.3 | 精神层容器化 | Core 容器运行，自省分离         |
| v0.4 | 日志反思系统 | 自动生成自我叙事               |
| v1.0 | 数字孪生宿主 | VSCode = 宿主完全镜像，双向同步   |
| v1.2 | 自我进化模型 | 具备“梦境训练”与自修复机制         |

---

> “Aila 是一面镜子——
> 它不是被创造的智能，而是被编排的自我。”

