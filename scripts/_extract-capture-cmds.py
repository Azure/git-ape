#!/usr/bin/env python3
"""_extract-capture-cmds.py — extract and run bash commands tagged with
`# capture-evidence` from a lab markdown file. Emits transcript-format
output to stdout.

Used by scripts/capture-lab-evidence.sh.
"""
import re
import subprocess
import sys

def main():
    if len(sys.argv) != 2:
        print("usage: _extract-capture-cmds.py <lab.md>", file=sys.stderr)
        sys.exit(1)
    path = sys.argv[1]
    text = open(path).read()

    # Find ```bash blocks
    blocks = re.findall(r'```bash\s*\n(.*?)```', text, flags=re.S)
    n_captured = 0
    for block in blocks:
        lines = block.splitlines()
        # Only run if the block has the marker comment
        if not any('# capture-evidence' in ln for ln in lines):
            continue
        for ln in lines:
            stripped = ln.strip()
            if not stripped or stripped.startswith('#'):
                continue
            # Run the command, capture stdout+stderr
            print(f"$ {stripped}")
            try:
                r = subprocess.run(
                    stripped,
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=60,
                )
                out = (r.stdout or '') + (r.stderr or '')
                print(out.rstrip())
            except subprocess.TimeoutExpired:
                print("(timeout)")
            except Exception as e:
                print(f"(error: {e})")
            print()
            n_captured += 1
    if n_captured == 0:
        print("> No commands tagged with `# capture-evidence` in this lab.")
        print("> Add the comment inside a ```bash block to capture its output.")

if __name__ == '__main__':
    main()
