#!/usr/bin/env python3

import os
import subprocess
import sys
import json

def run_command(cmd, cwd):
    print(f" Running: {cmd}")
    result = subprocess.run(cmd, shell=True, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        print(f" Error: Command failed: {cmd}")
        print(result.stderr)
        sys.exit(1)
    print(result.stdout)

def detect_and_build(code_path):
    code_path = os.path.abspath(code_path)
    print(f"🔍 Checking project in: {code_path}")

    if not os.path.exists(os.path.join(code_path, "package.json")):
        print(" Error: No package.json found. Not a Node.js project.")
        sys.exit(1)

    with open(os.path.join(code_path, "package.json")) as f:
        pkg = json.load(f)

    deps = pkg.get("dependencies", {})
    dev_deps = pkg.get("devDependencies", {})
    scripts = pkg.get("scripts", {})

    framework = None

    if "react" in deps or "react" in dev_deps:
        framework = "React"
    elif "next" in deps or "next" in dev_deps:
        framework = "Next.js"
    elif "angular" in deps or "@angular/core" in deps or "@angular/core" in dev_deps:
        framework = "Angular"
    else:
        print(" Framework not recognized. Only React, Next.js, or Angular supported.")
        sys.exit(1)

    print(f" Detected framework: {framework}")

    run_command("npm install", code_path)

    if framework == "Next.js":
        if "export" in scripts:
            run_command("npm run export", code_path)
        else:
            run_command("npm run build", code_path)
            print(" Warning: Next.js project may not be fully static without export.")
    else:
        run_command("npm run build", code_path)

    build_path = os.path.join(code_path, "build")
    dist_path = os.path.join(code_path, "dist")

    if not os.path.exists(build_path) and os.path.exists(dist_path):
        os.rename(dist_path, build_path)

    if not os.path.exists(build_path):
        print(f" Error: Expected build output not found at {build_path}")
        sys.exit(1)

    with open(os.path.join(code_path, "final_code_path.txt"), "w") as f:
        f.write(build_path)

    print(f" Build completed. Final build path: {build_path}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(" Error: Please provide the code path as argument.")
        print("Usage: python detect.py <CODE_PATH>")
        sys.exit(1)

    code_path = sys.argv[1]
    detect_and_build(code_path)