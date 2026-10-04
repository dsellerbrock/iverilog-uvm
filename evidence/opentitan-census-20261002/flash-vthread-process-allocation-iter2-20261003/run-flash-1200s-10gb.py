import json
import os
import signal
import subprocess
import time

vvp = "/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-unsafe-syntax-20260926/vvp/vvp"
matrix_dpi = "/private/tmp/pi/census11/build/runtime/lowrisc_dv_flash_ctrl_sim_0.1/matrix-dpi.so"
image = "/private/tmp/flash-read32-probe/matrix-runtime.vvp"
log_path = "/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-unsafe-syntax-20260926/evidence/opentitan-census-20261002/flash-vthread-process-allocation-iter2-20261003/flash.log"
repo_top = "/private/tmp/ot-corpus-after-fixes-20260929"
cmd = [vvp, "-d", matrix_dpi, image,
       "+UVM_NO_RELNOTES", "+UVM_VERBOSITY=UVM_LOW",
       "+cdc_instrumentation_enabled=1", "+smoke_test=1",
       "+UVM_TESTNAME=flash_ctrl_base_test",
       "+UVM_TEST_SEQ=flash_ctrl_smoke_vseq"]
env = os.environ.copy()
env["REPO_TOP"] = repo_top
start = time.monotonic()
peak = 0
memory_limit_hit = False
timeout_hit = False
last_report = start
with open(log_path, "wb") as log:
    proc = subprocess.Popen(cmd, cwd=repo_top, env=env, stdout=log,
                            stderr=subprocess.STDOUT)
    while proc.poll() is None:
        try:
            rss = int(subprocess.check_output(
                ["/bin/ps", "-o", "rss=", "-p", str(proc.pid)],
                text=True).strip()) * 1024
            peak = max(peak, rss)
        except (ValueError, subprocess.CalledProcessError):
            rss = 0
        elapsed = time.monotonic() - start
        if elapsed - (last_report - start) >= 30:
            size = os.path.getsize(log_path)
            print(json.dumps({"elapsed_seconds": round(elapsed, 1),
                              "rss_bytes": rss,
                              "peak_rss_bytes": peak,
                              "log_bytes": size}), flush=True)
            last_report = time.monotonic()
        if peak >= 10_000_000_000:
            memory_limit_hit = True
            proc.send_signal(signal.SIGTERM)
            break
        if elapsed >= 1200:
            timeout_hit = True
            proc.send_signal(signal.SIGTERM)
            break
        time.sleep(1)
    if proc.poll() is None:
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
    returncode = proc.wait()
print(json.dumps({"returncode": returncode,
                  "duration_seconds": round(time.monotonic() - start, 1),
                  "timed_out": timeout_hit,
                  "memory_limit_hit": memory_limit_hit,
                  "memory_limit_bytes": 10_000_000_000,
                  "peak_rss_bytes": peak,
                  "log": log_path}), flush=True)
