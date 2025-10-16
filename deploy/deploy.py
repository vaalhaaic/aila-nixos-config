
#!/usr/bin/env python3
"""Aila 安全部署工具

- 解析 scripts/deploy/mapping.yaml
- 支持 --check / --apply / --dry-run
- 默认 copy，不执行删除；若 delete=true 必须 --allow-delete 才会生效
- 避免写入受保护目录（/var/lib/aila 等）
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
PROTECTED_PREFIXES = [
    Path("/var/lib/aila"),
    Path("/srv"),
    Path("/etc"),
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
        raise RuntimeError("PyYAML 未安装。请执行: python3 -m pip install pyyaml")

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
            if resolved.is_relative_to(prefix):  # type: ignore[attr-defined]
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
        raise FileNotFoundError(f"源不存在: {src}")
    ensure_parent(dst)
    if dry_run:
        print(f"[dry-run] copy {src} -> {dst}")
        return
    if src.is_dir():
        shutil.copytree(src, dst, dirs_exist_ok=True)
    else:
        shutil.copy2(src, dst)


def apply_mapping(mappings: List[Mapping], *, dry_run: bool, allow_delete: bool) -> None:
    for item in mappings:
        print(f"[INFO] {item.src} -> {item.dst} (mode={item.mode}, delete={item.delete})")
        if not item.src.exists():
            print(f"[WARN] 源不存在，跳过: {item.src}")
            continue
        if is_protected(item.dst) and item.mode == "copy":
            print(f"[WARN] 目标位于受保护路径，请确认: {item.dst}")
        copy_tree(item.src, item.dst, dry_run=dry_run)
        if item.delete and allow_delete:
            if is_protected(item.dst):
                print(f"[WARN] 受保护目录禁止删除: {item.dst}")
            else:
                if dry_run:
                    print(f"[dry-run] would delete extraneous files under {item.dst}")
                else:
                    for child in item.dst.rglob('*'):
                        if child.is_file():
                            child.unlink()
        elif item.delete:
            print("[INFO] delete=true 但未启用 --allow-delete，已跳过清理。")


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Aila 安全部署工具")
    parser.add_argument("--mapping", default=str(MAPPING_DEFAULT), help="映射 YAML 文件路径")
    parser.add_argument("--apply", action="store_true", help="执行复制（否则仅 dry-run）")
    parser.add_argument("--dry-run", action="store_true", help="仅打印计划")
    parser.add_argument("--allow-delete", action="store_true", help="允许 delete=true 条目生效")

    args = parser.parse_args(argv)
    mappings = load_mapping(Path(args.mapping))
    dry = args.dry_run or not args.apply
    apply_mapping(mappings, dry_run=dry, allow_delete=args.allow_delete)
    if dry and args.apply:
        print("[INFO] dry-run 模式：如需执行复制，请移除 --dry-run")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
