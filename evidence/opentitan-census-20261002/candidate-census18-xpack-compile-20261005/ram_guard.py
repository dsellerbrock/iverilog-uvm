#!/usr/bin/env python3
import os, signal, subprocess, sys, time
from pathlib import Path

minimum_free = int(sys.argv[1])
log_path = Path(sys.argv[2])
command = sys.argv[3:]
if not command:
    raise SystemExit("missing command after log path")

def free_percent():
    output = subprocess.check_output(["/usr/bin/memory_pressure"], text=True)
    line = next(row for row in output.splitlines() if "System-wide memory free percentage:" in row)
    return int(line.split(":", 1)[1].strip().rstrip("%"))

def stop_group(proc):
    try:
        os.killpg(proc.pid, signal.SIGINT)
        proc.wait(timeout=15)
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGTERM)
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid, signal.SIGKILL)
            proc.wait()

with log_path.open("w", buffering=1) as log:
    started = time.monotonic()
    proc = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    print(f"RAM guard: min_free={minimum_free}%, pid={proc.pid}, log={log_path}", flush=True)
    log.write(f"RAM guard started; min_free={minimum_free}%; command={command!r}\n")
    last_report = 0.0
    while proc.poll() is None:
        try:
            free = free_percent()
        except Exception as error:
            log.write(f"RAM guard monitor failed: {error!r}; stopping child group\n")
            print("RAM guard monitor failed; stopping child group", flush=True)
            stop_group(proc)
            raise SystemExit(74)
        elapsed = int(time.monotonic() - started)
        if free < minimum_free:
            log.write(f"RAM guard tripped at free={free}%; stopping child group\n")
            print(f"RAM guard tripped at free={free}%; stopping child group", flush=True)
            stop_group(proc)
            raise SystemExit(75)
        if time.monotonic() - last_report >= 30:
            print(f"RAM guard: free={free}%, elapsed={elapsed}s", flush=True)
            log.write(f"RAM guard sample: free={free}%, elapsed={elapsed}s\n")
            last_report = time.monotonic()
        time.sleep(5)
    print(f"RAM guard: command exited {proc.returncode}, elapsed={int(time.monotonic()-started)}s", flush=True)
    log.write(f"RAM guard finished with exit={proc.returncode}\n")
    raise SystemExit(proc.returncode)
