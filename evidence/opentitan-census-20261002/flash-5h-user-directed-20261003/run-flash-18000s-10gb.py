import hashlib
import json
import os
import re
import signal
import subprocess
import time
from pathlib import Path

root = Path('/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-unsafe-syntax-20260926')
vvp = root / 'vvp/vvp'
matrix_dpi = Path('/private/tmp/pi/census11/build/runtime/lowrisc_dv_flash_ctrl_sim_0.1/matrix-dpi.so')
image = Path('/private/tmp/flash-read32-probe/matrix-runtime.vvp')
repo_top = Path('/private/tmp/ot-corpus-after-fixes-20260929')
out = root / 'evidence/opentitan-census-20261002/flash-5h-user-directed-20261003'
log_path = out / 'flash.log'
progress_path = out / 'progress.jsonl'
result_path = out / 'result.json'
cmd = [str(vvp), '-d', str(matrix_dpi), str(image),
       '+UVM_NO_RELNOTES', '+UVM_VERBOSITY=UVM_LOW',
       '+cdc_instrumentation_enabled=1', '+smoke_test=1',
       '+UVM_TESTNAME=flash_ctrl_base_test',
       '+UVM_TEST_SEQ=flash_ctrl_smoke_vseq']
env = os.environ.copy()
env['REPO_TOP'] = str(repo_top)
wall_cap = 18000
rss_cap = 10_000_000_000
start = time.monotonic()
peak = 0
memory_limit_hit = False
timeout_hit = False
stop_reason = None
last_report = start

def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

with open(log_path, 'wb') as log, open(progress_path, 'w', buffering=1) as progress:
    proc = subprocess.Popen(cmd, cwd=repo_top, env=env, stdout=log,
                            stderr=subprocess.STDOUT)
    while proc.poll() is None:
        try:
            rss = int(subprocess.check_output(
                ['/bin/ps', '-o', 'rss=', '-p', str(proc.pid)], text=True).strip()) * 1024
            peak = max(peak, rss)
        except (ValueError, subprocess.CalledProcessError):
            rss = 0
        elapsed = time.monotonic() - start
        if elapsed - (last_report - start) >= 30:
            row = {'elapsed_seconds': round(elapsed, 1),
                   'rss_bytes': rss, 'peak_rss_bytes': peak,
                   'log_bytes': log_path.stat().st_size}
            progress.write(json.dumps(row) + '\n')
            print(json.dumps(row), flush=True)
            last_report = time.monotonic()
        if peak >= rss_cap:
            memory_limit_hit = True
            stop_reason = 'rss_cap'
            proc.send_signal(signal.SIGTERM)
            break
        if elapsed >= wall_cap:
            timeout_hit = True
            stop_reason = 'wall_cap'
            proc.send_signal(signal.SIGTERM)
            break
        time.sleep(1)
    if proc.poll() is None:
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
    returncode = proc.wait()

duration = round(time.monotonic() - start, 1)
log_text = log_path.read_text(errors='replace')
pass_marker = 'TEST PASSED CHECKS' in log_text
failed_marker = 'TEST FAILED CHECKS' in log_text
errors = [line for line in log_text.splitlines() if re.match(r'^\s*UVM_ERROR\s*@', line)]
fatals = [line for line in log_text.splitlines() if re.match(r'^\s*UVM_FATAL\s*@', line)]
seed_match = re.search(r'DefaultSeed\s*=\s*(0x[0-9a-fA-F]+),\s*DefaultSeedLocal\s*=\s*(0x[0-9a-fA-F]+)', log_text)
ops = re.findall(r'Starting flash_ctrl op:\s*([^\n]+)', log_text)
markers = re.findall(r'UVM_INFO @\s*([0-9.]+ ns): \(flash_ctrl_scoreboard\.sv:[^\n]+', log_text)
clean_pass = (returncode == 0 and not timeout_hit and not memory_limit_hit
              and pass_marker and not errors and not fatals and not failed_marker)
result = {
    'command': cmd,
    'runtime_sha256': sha(vvp),
    'flash_image_sha256': sha(image),
    'dpi_library_sha256': sha(matrix_dpi),
    'test': 'flash_ctrl_base_test',
    'sequence': 'flash_ctrl_smoke_vseq',
    'seed': {'default': seed_match.group(1), 'local': seed_match.group(2)} if seed_match else None,
    'wall_cap_seconds': wall_cap,
    'rss_cap_bytes': rss_cap,
    'duration_seconds': duration,
    'returncode': returncode,
    'timed_out': timeout_hit,
    'memory_limit_hit': memory_limit_hit,
    'stop_reason': stop_reason,
    'peak_rss_bytes': peak,
    'operation_starts': ops,
    'last_scoreboard_sim_time_ns': markers[-1].split()[0] if markers else None,
    'pass_marker': pass_marker,
    'failed_marker': failed_marker,
    'uvm_error_lines': errors,
    'uvm_fatal_lines': fatals,
    'clean_checked_pass': clean_pass,
    'log_bytes': log_path.stat().st_size,
    'log': 'flash.log',
    'progress': 'progress.jsonl'
}
result_path.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: result[k] for k in ('returncode','duration_seconds','timed_out','memory_limit_hit','stop_reason','peak_rss_bytes','operation_starts','pass_marker','failed_marker','clean_checked_pass')}), flush=True)
