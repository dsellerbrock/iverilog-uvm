#!/usr/bin/env python3
"""Reject malformed state-foreach IR and preserve a failed solve's stack."""
import os
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[2]
vvp = os.environ.get('VVP', str(repo / 'vvp/vvp'))
fixture = '''
:ivl_version "13.0 (devel)";
:ivl_delay_selection "TYPICAL";
:vpi_time_precision + 0;
:vpi_module "system";
S_top .scope module, "top" "top" 1 1;
 .timescale 0 0;
C_req .class "req" "$unit.req" [1]
  0: "addr", "q8:rb32"
 ;
C_owner .class "owner" "$unit.owner" [1]
  0: "ranges", "q0:Qo"
 ;
C_row .class/struct "row" [1]
  0: "lo", "q0:b32"
 ;
 .scope S_top;
T_0 ;
    RECEIVER
    %new/cobj C_owner;
    %new/queue "o";
    %dup/obj/ref;
    %new/cobj C_row;
    %pushi/vec4 11, 0, 32;
    %store/prop/v 0, 32;
    %store/qo/b/obj;
    %store/prop/obj 0, 0;
    %randomize/with/objects "PAYLOAD", VALUES, OBJECTS;
    %cmpi/u 0, 0, 32;
    %jmp/1 T_ok, 4;
    %vpi_call/w 1 1 "$fatal", 32'sb00000000000000000000000000000001, "invalid metadata succeeded" {0 0 0 0};
T_ok ;
    %vpi_call/w 1 1 "$display", "PASSED" {0 0 0 0};
    %end;
 .thread T_0;
:file_names 2;
 "N/A";
 "state_foreach_invariants.vvp";
'''
malformed = [
    '(qforeach 0 0 (impl c:nope c:0:1))',
    '(qforeach 0 0 (bogus))',
    '(qforeach 0 0 bogus)',
    '(qforeach 0 0 (eq c:1))',
    '(qforeach 0 0 c:1:0)',
    '(qforeach 0 0 c:1:65)',
    '(qforeach 0 0 c:18446744073709551616:64)',
    '(qforeach 0 0 (eq v:-1:32 c:0))',
    '(qforeach 0 0 (eq (qfield qf:-0:0:32 L) c:0))',
    '(qforeach 1 0 c:1)',
    '(qforeach 0 0 (eq (qfield qf:1:0:32 L) c:0))',
    '(qforeach 0 0 (eq p:0:0 c:0))',
]
cases = [(ir, 0, 1, '%new/cobj C_req;', 0,
          'ERROR: state foreach constraint: malformed object/constraint metadata.\n')
         for ir in malformed]
cases += [
    ('(qforeach 0 0 c:1)', 0, 1, '%null;', 0,
     'ERROR: state foreach constraint: null/non-class randomize receiver.\n'),
    ('(qforeach 0 0 c:1)', 1, 1, '%new/cobj C_req;', 1,
     'VVP error: malformed %randomize/with/objects stack counts.\n'),
    ('(qforeach 0 0 c:1)', 0, 2, '%new/cobj C_req;', 1,
     'VVP error: malformed %randomize/with/objects stack counts.\n'),
]
with tempfile.TemporaryDirectory(prefix='state-foreach-') as tmp:
    for i, (ir, values, objects, receiver, rc, stderr) in enumerate(cases):
        path = Path(tmp) / f'case-{i}.vvp'
        text = fixture.replace('PAYLOAD', ir).replace('VALUES', str(values))
        text = text.replace('OBJECTS', str(objects)).replace('RECEIVER', receiver)
        path.write_text(text)
        run = subprocess.run([vvp, str(path)], capture_output=True, text=True, timeout=10)
        stdout = 'PASSED\n' if rc == 0 else ''
        assert (run.returncode, run.stdout, run.stderr) == (rc, stdout, stderr), (
            i, ir, run.returncode, run.stdout, run.stderr)
print(f'PASS state foreach runtime invariants ({len(cases)}/{len(cases)})')
