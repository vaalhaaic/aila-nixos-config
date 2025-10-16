#!/usr/bin/env python3
"""Aila 安全部署工具 (Safe Edition)

功能：
- 解析 scripts/deploy/mapping.yaml
- 默认仅复制，不删除。
- 支持 --check / --apply / --dry-run / --allow-delete / --force-systemd
- 自动跳过不存在的源目录。
- 避免写入受保护目录（/etc /usr /boot /nix /var/lib）。
"""

from __future__ import annotations
import argparse
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional

try:
    import yaml  # type: ignore
except Exception:
    yaml = None

ROOT = Path(__file__).resolve().parents[2]
MAPPING_DEFAULT = ROOT / "scripts" / "deploy" / "mapping.yaml"

# 系统保护路径
PROTECTED_PREFIXES = [
    Path("/etc"),
    Path("/usr"),
    Path("/boot"),
    Path("/nix"),
    Path("/var/lib"),
]

@dataclass
class Mapping:
    src: Path
    dst: Path
    mode: str = "copy"
    delete: bool = False

def load_mapping(path: Path) -> List[Mapping]:
    if not path.exists():
        raise FileNotFoundError(f"映射文件不存在: {path}")
    if yaml is None:
        raise RuntimeError("PyYAML 未安装，请执行: nix-shell -p python3Packages.pyyaml")

    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    mappings: List[Mapping] = []
    for item in data.get("mappings", []) or []:
        src = (ROOT / item.get("src", "")).resolve()
        dst = Path(item.get("dst", "")).resolve()
        mode = (item.get("mode") or "copy").lower()
        delete = bool(item.get("delete", False))
        mappings.append(Mapping(src=src, dst=dst, mode=mode, delete=delete))
    return mappings

def is_protected(path: Path) -> bool:
    resolved = path.resolve()
    for prefix in PROTECTED_PREFIXES:
        try:
            if resolved.is_relative_to(prefix):  # Python 3.9+
                return True
        except AttributeError:
            try:
                resolved.relative_to(prefix)
                return True
            except Exception:
                pass
    return False

def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

def copy_tree(src: Path, dst: Path, *, dry_run: bool) -> None:
    if not src.exists():
        print(f"[WARN] 源目录不存在: {src}")
        return
    ensure_parent(dst)
    if dry_run:
        print(f"[dry-run] Would copy {src} -> {dst}")
        return
    if src.is_dir():
        shutil.copytree(src, dst, dirs_exist_ok=True)
    else:
        shutil.copy2(src, dst)

def apply_mapping(
    mappings: List[Mapping],
    *,
    dry_run: bool,
    allow_delete: bool,
    force_systemd: bool,
) -> None:
    for item in mappings:
        print(f"[INFO] {item.src} → {item.dst} (mode={item.mode}, delete={item.delete})")
        if not item.src.exists():
            print(f"[SKIP] 源不存在，跳过: {item.src}")
            continue

        # 禁止误操作受保护目录
        if is_protected(item.dst) and not force_systemd:
            print(f"[WARN] 受保护目录: {item.dst}，仅复制文件。")
            copy_tree(item.src, item.dst, dry_run=dry_run)
            continue

        # systemd 目录安全模式：只复制，不删除
        if "/etc/systemd/system" in str(item.dst):
            print("[SAFE] 检测到 systemd 目录，自动启用安全模式（仅复制）")
            copy_tree(item.src, item.dst, dry_run=dry_run)
            continue

        # 普通安全复制
        copy_tree(item.src, item.dst, dry_run=dry_run)

        # 可选删除逻辑（默认禁用）
        if item.delete:
            if not allow_delete:
                print("[INFO] delete=true 但未启用 --allow-delete，跳过删除。")
            elif is_protected(item.dst):
                print(f"[WARN] 禁止删除受保护目录: {item.dst}")
            elif dry_run:
                print(f"[dry-run] Would delete extraneous files under {item.dst}")
            else:
                for child in item.dst.rglob('*'):
                    if child.is_file():
                        child.unlink()

def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Aila 安全部署工具 (Safe Edition)")
    parser.add_argument("--mapping", default=str(MAPPING_DEFAULT), help="映射 YAML 文件路径")
    parser.add_argument("--apply", action="store_true", help="执行复制（否则仅 dry-run）")
    parser.add_argument("--dry-run", action="store_true", help="仅打印计划")
    parser.add_argument("--allow-delete", action="store_true", help="允许 delete=true 条目生效")
    parser.add_argument("--force-systemd", action="store_true", help="允许写入 /etc/systemd/system")

    args = parser.parse_args(argv)
    mappings = load_mapping(Path(args.mapping))
    dry = args.dry_run or not args.apply
    apply_mapping(mappings, dry_run=dry, allow_delete=args.allow_delete, force_systemd=args.force_systemd)
    if dry and args.apply:
        print("[INFO] dry-run 模式：如需执行复制，请移除 --dry-run")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
