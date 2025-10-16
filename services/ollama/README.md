
````markdown
# 🧠 Aila Ollama Service

## 功能
本模块提供大语言模型（LLM）的推理与对话接口，支持 GPU 加速。

## 运行方法

### 手动运行
```bash
cd /aila/service/ollama
nix develop
ollama serve
````

### 自动运行

通过 systemd 管理：

```bash
sudo systemctl enable --now aila-ollama.service
```

### 检查状态

```bash
systemctl status aila-ollama
```

````

---

## 🧭 阶段 5️⃣：定义 deploy 映射（告诉系统去哪儿）

在 `Aila/deploy/mapping.yaml` 添加：

```yaml
mappings:
  - src: service/ollama/
    dst: /aila/service/ollama/
    sudo: true
  - src: service/ollama/systemd/
    dst: /etc/systemd/system/
    sudo: true
````

💡 表示：

- `flake.nix` 和 README 会同步到 `/aila/service/ollama`
    
- `systemd` 文件会同步到 `/etc/systemd/system`
    
