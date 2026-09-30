#!/bin/zsh
cd /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-unsafe-syntax-20260926
export PYTHONHASHSEED=2
/Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313/bin/python scripts/opentitan_matrix.py \
  --opentitan-root /private/tmp/ot-hmac-live-counters-selected-20260929/source \
  --build-root /private/tmp/ot-hmac-live-counters-selected-rerun-20260929/work --iverilog /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-unsafe-syntax-20260926/local-install/bin/iverilog \
  --uvm-home /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/third_party/uvm-releases/sources/1.2/uvm-1.2/src \
  --fusesoc /Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313/bin/fusesoc \
  --lane runtime --core lowrisc:dv:hmac_sim:0.1 --commercial-unsafe --jobs 1 \
  --runtime-timeout 300 --runtime-memory-mib 4096 \
  --result-json /private/tmp/ot-hmac-live-counters-selected-rerun-20260929/selected-result.json --result-md /private/tmp/ot-hmac-live-counters-selected-rerun-20260929/selected-result.md > /private/tmp/ot-hmac-live-counters-selected-rerun-20260929/matrix-console.log 2>&1
echo "exit=$?" > /private/tmp/ot-hmac-live-counters-selected-rerun-20260929/DONE
