#!/usr/bin/env python3
"""Discover which stacks a repository contains, so agent rules, hooks and CI never hardcode paths.

Usage:
  detect-stacks.py                 print JSON describing detected stacks
  detect-stacks.py --changed BASE  print the names of stacks with changes vs BASE (git ref),
                                   plus uncommitted/untracked files; one name per line
"""
import json
import os
import subprocess
import sys

SKIP = {".git", "node_modules", "bin", "obj", "dist", ".claude", "vendor", ".sfdx", ".sf", "test-results", "playwright-report"}


def walk(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP]
        yield dirpath, filenames


def rel(root, path):
    r = os.path.relpath(path, root)
    return "." if r == "." else r


def detect(root="."):
    out = {"salesforce": None, "dotnet": [], "react": [], "wordpress": []}

    sfdx = os.path.join(root, "sfdx-project.json")
    if os.path.isfile(sfdx):
        try:
            data = json.load(open(sfdx))
            dirs = [d["path"] for d in data.get("packageDirectories", []) if "path" in d]
        except (ValueError, OSError):
            dirs = []
        out["salesforce"] = {"packageDirs": dirs or ["force-app"]}

    csproj_dirs = []
    for dirpath, files in walk(root):
        names = [f for f in files]
        if any(f.endswith(".csproj") for f in names):
            csproj_dirs.append(dirpath)
        if "package.json" in names:
            try:
                pkg = json.load(open(os.path.join(dirpath, "package.json")))
                deps = {**pkg.get("dependencies", {}), **pkg.get("devDependencies", {})}
                if "react" in deps:
                    out["react"].append({"root": rel(root, dirpath)})
            except (ValueError, OSError):
                pass
        for f in names:
            if f.endswith(".php"):
                try:
                    head = open(os.path.join(dirpath, f), errors="ignore").read(2048)
                except OSError:
                    continue
                if "Plugin Name:" in head:
                    r = rel(root, dirpath)
                    if not any(w["root"] == r for w in out["wordpress"]):
                        out["wordpress"].append({"root": r})
            if f == "style.css":
                try:
                    if "Theme Name:" in open(os.path.join(dirpath, f), errors="ignore").read(2048):
                        r = rel(root, dirpath)
                        if not any(w["root"] == r for w in out["wordpress"]):
                            out["wordpress"].append({"root": r})
                except OSError:
                    pass

    # .NET: a "service root" is the directory two levels above src/<Project>/<x>.csproj or tests/<Project>;
    # simplest robust rule: group csproj dirs by their nearest ancestor that has src/ and tests/, else the dir itself.
    roots = {}
    for d in csproj_dirs:
        parts = os.path.normpath(d).split(os.sep)
        anchor = d
        for i in range(len(parts) - 1, 0, -1):
            if parts[i] in ("src", "tests"):
                anchor = os.sep.join(parts[:i]) or "."
                break
        entry = roots.setdefault(anchor, {"root": rel(root, anchor), "tests": []})
        if any(f.endswith(".csproj") and ("test" in f.lower()) for f in os.listdir(d)):
            entry["tests"].append(rel(root, d))
    out["dotnet"] = sorted(roots.values(), key=lambda e: e["root"])
    return out


def under(path, prefix):
    prefix = prefix.rstrip("/")
    return prefix == "." or path == prefix or path.startswith(prefix + "/")


def changed_files(base):
    files = set()
    for cmd in (["git", "diff", "--name-only", f"{base}...HEAD"], ["git", "diff", "--name-only", "HEAD"],
                ["git", "ls-files", "--others", "--exclude-standard"]):
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode == 0:
            files.update(l for l in r.stdout.splitlines() if l)
    return files


def stacks_changed(info, files):
    hit = []
    sf = info["salesforce"]
    if sf and any(under(f, d) for f in files for d in sf["packageDirs"]):
        hit.append("salesforce")
    for name in ("dotnet", "react", "wordpress"):
        if any(under(f, e["root"]) for f in files for e in info[name]):
            hit.append(name)
    return hit


if __name__ == "__main__":
    info = detect(".")
    if len(sys.argv) >= 2 and sys.argv[1] == "--changed":
        base = sys.argv[2] if len(sys.argv) > 2 else "HEAD"
        print("\n".join(stacks_changed(info, changed_files(base))))
    else:
        print(json.dumps(info, indent=2))
