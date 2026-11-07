#!/usr/bin/env python3
"""Fail if C/C++ source calls a POSIX function that MinGW does not provide.

The Windows builds (MINGW64/UCRT64/CLANG64) run only after merge, nightly or
on demand, because they take hours. A call such as open_memstream() builds
fine on Linux and macOS and only fails there (#442's PR #2652 broke all three
on main, fixed by #2691). This catches that class in the fast PR job.

A call is allowed inside a preprocessor branch that is never compiled on
Windows: #ifndef _WIN32 / #if !defined(_WIN32), every #elif/#else after an
#ifdef _WIN32 branch (same for __WIN32__ and __MINGW32__), or a branch whose
condition tests a configure HAVE_ macro (configure decides it per platform).
getline/getdelim are checked only in .c files: in C++ they are std::getline.
Anything else is reported with file:line.
"""
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent

# Not in the MinGW-w64 CRT or its POSIX headers (the MSVCRT-style _xxx
# replacements, e.g. _pipe, have different names or signatures).
MISSING = """open_memstream fmemopen open_wmemstream fork vfork getline getdelim
mkdtemp realpath sigaction sigemptyset sigprocmask mmap munmap posix_memalign
readlink symlink lstat getpwnam getpwuid getuid geteuid dlopen dlsym dlclose
setenv unsetenv strsep""".split()
call = re.compile(r"(?<![\w.>:])(" + "|".join(MISSING) + r")\s*\(")
C_ONLY = {"getline", "getdelim"}

WIN = r"(_WIN32|__WIN32__|__MINGW32__)"
if_not_win = re.compile(r"#\s*(ifndef\s+" + WIN + r"\b|if\s+!\s*defined\s*\(?\s*" + WIN + r")")
if_win = re.compile(r"#\s*(ifdef\s+" + WIN + r"\b|if\s+defined\s*\(?\s*" + WIN + r")")
if_any = re.compile(r"#\s*if")
have = re.compile(r"#\s*(if|ifdef|elif)\b.*\bHAVE_\w+")
else_ = re.compile(r"#\s*(else|elif)\b")
endif = re.compile(r"#\s*endif\b")

SKIP = ("ivtest/", "tests/", "uvm-core/", "evidence/", "build", "local-install", ".git/")


def code(text):
    # blank out comments and string literals but keep line numbers
    def blank(m):
        return re.sub(r"[^\n]", " ", m.group(0))
    text = re.sub(r"/\*.*?\*/", blank, text, flags=re.S)
    text = re.sub(r'"(\\.|[^"\\\n])*"', blank, text)
    return re.sub(r"//[^\n]*", "", text)


def scan(path):
    bad = []
    # per open #if, the current branch: "win" (Windows only), "notwin" (never on Windows),
    # "guard" (a configure HAVE_ test), "other"; "after_win" = a branch after a Windows one
    stack = []
    for n, line in enumerate(code(path.read_text(errors="ignore")).split("\n"), 1):
        s = line.strip()
        if if_not_win.match(s):
            stack.append("notwin")
        elif if_win.match(s):
            stack.append("win")
        elif have.match(s) and s.lstrip("# ").startswith("if"):
            stack.append("guard")
        elif if_any.match(s):
            stack.append("other")
        elif else_.match(s) and stack:
            top = stack[-1]
            if top in ("win", "after_win"):
                stack[-1] = "after_win"
            elif have.match(s):
                stack[-1] = "guard"
            else:
                stack[-1] = "other"
        elif endif.match(s) and stack:
            stack.pop()
        elif not set(stack) & {"notwin", "after_win", "guard"}:
            for m in call.finditer(line):
                if m.group(1) in C_ONLY and path.suffix != ".c":
                    continue
                bad.append((n, m.group(1)))
    return bad


found = 0
files = 0
for f in sorted(root.rglob("*")):
    rel = f.relative_to(root).as_posix()
    if f.suffix not in (".c", ".cc", ".cpp", ".h", ".y", ".lex") or rel.startswith(SKIP) or not f.is_file():
        continue
    files += 1
    for n, name in scan(f):
        print(f"{rel}:{n}: {name}() does not exist on MinGW; guard it with #ifndef _WIN32 or use a portable call")
        found += 1

if found:
    sys.exit(1)
print(f"win-posix: {files} C/C++ sources, no unguarded calls to {len(MISSING)} POSIX functions MinGW lacks")
