import datetime
import json
import os
import signal
import subprocess
import time

vvp = "/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-unsafe-syntax-20260926/vvp/vvp"
matrix_dpi = "/private/tmp/pi/census11/build/runtime/lowrisc_dv_flash_ctrl_sim_0.1/matrix-dpi.so"
image = "/private/tmp/flash-read32-probe/matrix-runtime.vvp"
repo_top = "/private/tmp/ot-corpus-after-fixes-20260929"
artifact_dir = "/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-unsafe-syntax-20260926/evidence/opentitan-census-20261002/flash-vpi-scope-cache-20261003"
log_path = os.path.join(artifact_dir, "flash-1200s-10gb-profile-20261003.log")
result_path = os.path.join(artifact_dir, "flash-1200s-10gb-profile-result.json")
progress_path = os.path.join(artifact_dir, "flash-1200s-10gb-profile-progress.jsonl")
sample_times = [120, 300, 540, 780, 1020]
cmd = ["/usr/bin/stdbuf", "-oL", "-eL", vvp, "-d", matrix_dpi, image,
       "+UVM_NO_RELNOTES", "+UVM_VERBOSITY=UVM_LOW",
       "+cdc_instrumentation_enabled=1", "+smoke_test=1",
       "+UVM_TESTNAME=flash_ctrl_base_test",
       "+UVM_TEST_SEQ=flash_ctrl_smoke_vseq"]
env = os.environ.copy()
env["REPO_TOP"] = repo_top
start = time.monotonic()
start_utc = datetime.datetime.now(datetime.timezone.utc).isoformat()
peak = 0
samples = []
next_sample = 0
last_status = 0
returncode = None
termination = None
with open(log_path, "wb") as log, open(progress_path, "w", buffering=1) as progress:
    proc = subprocess.Popen(cmd, cwd=repo_top, env=env, stdout=log,
                            stderr=subprocess.STDOUT, start_new_session=True)
    print(json.dumps({"event": "started", "pid": proc.pid,
                      "utc": start_utc, "command": cmd,
                      "log": log_path}), flush=True)
    while proc.poll() is None:
        elapsed = time.monotonic() - start
        try:
            rss = int(subprocess.check_output(
                ["/bin/ps", "-o", "rss=", "-p", str(proc.pid)],
                text=True).strip()) * 1024
            peak = max(peak, rss)
        except (ValueError, subprocess.CalledProcessError):
            rss = 0
        if next_sample < len(sample_times) and elapsed >= sample_times[next_sample]:
            sample_path = os.path.join(
                artifact_dir, f"flash-cpu-sample-{next_sample + 1}-20261003.txt")
            sample_start = time.monotonic()
            captured = subprocess.run(
                ["/usr/bin/sample", str(proc.pid), "10", "1", "-fullPaths",
                 "-file", sample_path], text=True, capture_output=True)
            item = {"sample": next_sample + 1,
                    "scheduled_elapsed_s": sample_times[next_sample],
                    "actual_elapsed_s": round(time.monotonic() - start, 1),
                    "capture_duration_s": round(time.monotonic() - sample_start, 1),
                    "returncode": captured.returncode,
                    "bytes": os.path.getsize(sample_path)
                             if os.path.exists(sample_path) else 0,
                    "path": sample_path,
                    "stderr": captured.stderr[-1000:]}
            samples.append(item)
            event = {"event": "sample", **item}
            progress.write(json.dumps(event) + "\n")
            print(json.dumps(event), flush=True)
            next_sample += 1
            continue
        if peak >= 10_000_000_000:
            termination = "rss_limit"
            os.killpg(proc.pid, signal.SIGTERM)
            break
        if elapsed >= 1200:
            termination = "wall_limit"
            os.killpg(proc.pid, signal.SIGTERM)
            break
        if elapsed - last_status >= 30:
            event = {"event": "progress", "elapsed_s": round(elapsed, 1),
                     "rss_bytes": rss, "peak_rss_bytes": peak,
                     "log_bytes": os.path.getsize(log_path)}
            progress.write(json.dumps(event) + "\n")
            print(json.dumps(event), flush=True)
            last_status = elapsed
        time.sleep(1)
    if proc.poll() is None:
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            termination = (termination or "kill_after_sigterm")
            os.killpg(proc.pid, signal.SIGKILL)
    returncode = proc.wait()
result = {"returncode": returncode,
          "termination": termination,
          "start_utc": start_utc,
          "duration_seconds": round(time.monotonic() - start, 1),
          "peak_rss_bytes": peak,
          "limit_seconds": 1200,
          "rss_limit_bytes": 10_000_000_000,
          "samples": samples,
          "log": log_path,
          "progress": progress_path}
with open(result_path, "w") as out:
    json.dump(result, out, indent=2)
    out.write("\n")
print(json.dumps({"event": "finished", **result}), flush=True)
