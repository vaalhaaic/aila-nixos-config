#!/usr/bin/env python3
# ===============================================================
# 🧭 validate_mapping.py
# ---------------------------------------------------------------
# 用于验证 deploy/mapping.yaml 的所有路径映射是否存在与可写
# ===============================================================

import os
import yaml
import subprocess
from termcolor import colored

MAP_FILE = "deploy/mapping.yaml"

def check_path(path):
    return os.path.exists(path)

def check_writeable(path):
    parent = os.path.dirname(path.rstrip("/"))
    return os.access(parent or ".", os.W_OK)

def main():
    print(colored(f"🧩 Validating {MAP_FILE} ...", "cyan"))
    if not os.path.exists(MAP_FILE):
        print(colored("❌ mapping.yaml 不存在", "red"))
        return

    with open(MAP_FILE, "r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f)

    errors = 0
    for m in cfg.get("mappings", []):
        name = m.get("name", "(unnamed)")
        src = m["src"]
        dst = m["dst"]
        sudo = m.get("sudo", False)

        print(colored(f"\n🔹 {name}", "yellow"))
        print(f"  src: {src}")
        print(f"  dst: {dst}")

        # 检查源目录
        if not check_path(src):
            print(colored(f"  ❌ 源目录不存在: {src}", "red"))
            errors += 1
        else:
            print(colored("  ✅ 源目录存在", "green"))

        # 检查目标目录
        if not check_path(dst):
            print(colored(f"  ⚠️ 目标目录不存在（可自动创建）: {dst}", "yellow"))
        else:
            print(colored("  ✅ 目标目录存在", "green"))

        # 检查权限
        if sudo and os.geteuid() != 0:
            print(colored("  ⚠️ 需要 sudo 权限", "yellow"))
        elif check_writeable(dst):
            print(colored("  ✅ 目标路径可写", "green"))
        else:
            print(colored("  ❌ 无法写入目标路径", "red"))
            errors += 1

    print("\n" + ("✅ 全部路径验证通过！" if errors == 0 else f"❌ 检测到 {errors} 个问题"))
    print("-----------------------------------------------------------")
    print("💡 提示: 可执行 `sudo python3 scripts/validate_mapping.py` 进行权限验证")

if __name__ == "__main__":
    main()
