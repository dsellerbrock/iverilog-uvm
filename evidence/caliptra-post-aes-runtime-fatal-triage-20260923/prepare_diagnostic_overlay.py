#!/usr/bin/env python3
"""Prepare copied Caliptra runtime probes; never compile or simulate."""

from hashlib import sha256
from pathlib import Path
import json
import re
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: prepare_diagnostic_overlay.py RESET_PROFILE /tmp/OUTPUT_DIR")

campaign = Path(__file__).resolve().parents[2]
source = campaign.parent / "caliptra-rtl"
baseline = campaign / "evidence/caliptra-l0-icarus-baseline-20260923/caliptra_top_tb_icarus_profile.vf"
reset_profile = Path(sys.argv[1]).resolve()
output = Path(sys.argv[2]).resolve()
if not output.is_relative_to(Path("/tmp").resolve()) or output.exists():
    raise SystemExit("output must be a new directory under /tmp")

paths = {
    "src/riscv_core/veer_el2/rtl/dec/el2_dec_tlu_ctl.sv": "da4714790a670ba4dd1fc105342da921c976747c80af6af1ba9a4b73f1a06087",
    "src/soc_ifc/rtl/soc_ifc_reg.sv": "c5aa7e9c0914bafe144d7ad9b51fdb070836f8211a8b7aef037c4fa65d201f77",
    "src/riscv_core/veer_el2/rtl/lsu/el2_lsu_stbuf.sv": "4a7e95f2a16ec57bec3670143572fbb11b54b9607ebefb78568e935f003efb7b",
    "src/soc_ifc/rtl/soc_ifc_reg_pkg.sv": "13956d2524e09e77fd20619c7fe665fa40798e4a1825367bcb39da52e28c44bb",
    "src/integration/tb/caliptra_top_tb_soc_bfm.sv": "e0c60be6ad48681458ca38093a494ae263304997e658c5eefa006881da10ae06",
}

def digest(data):
    return sha256(data).hexdigest()

for name, expected in paths.items():
    if digest((source / name).read_bytes()) != expected:
        raise SystemExit(f"pinned source hash changed: {name}")
if digest(baseline.read_bytes()) != "577861eb1c4c9a26ada2379f55e3215d097e1cc317804a0f3155c3786ed381f2":
    raise SystemExit("baseline filelist hash changed")

# Require the earlier reset overlay, with its exact one-line BFM change.
original_bfm = (source / "src/integration/tb/caliptra_top_tb_soc_bfm.sv").read_bytes()
old_bfm = b"    initial begin\n        cptra_pwrgood = 1'b0;\n        BootFSM_BrkPoint ="
new_bfm = old_bfm.replace(b"cptra_pwrgood", b"#0 cptra_pwrgood")
if original_bfm.count(old_bfm) != 1:
    raise SystemExit("reset BFM anchor changed")
baseline_lines = baseline.read_bytes().splitlines(keepends=True)
reset_lines = reset_profile.read_bytes().splitlines(keepends=True)
bfm_entry = b"${CALIPTRA_ROOT}/src/integration/tb/caliptra_top_tb_soc_bfm.sv"
indices = [i for i, line in enumerate(baseline_lines) if line.strip() == bfm_entry]
if len(indices) != 1 or len(reset_lines) != len(baseline_lines):
    raise SystemExit("reset profile shape changed")
bfm_index = indices[0]
reset_bfm = Path(reset_lines[bfm_index].decode().strip())
if not reset_bfm.is_absolute() or any(
    line != reset_lines[i] for i, line in enumerate(baseline_lines) if i != bfm_index
):
    raise SystemExit("reset profile differs beyond its BFM entry")
if reset_bfm.read_bytes() != original_bfm.replace(old_bfm, new_bfm):
    raise SystemExit("reset BFM does not match the approved one-line overlay")

# List top-level packed hwif_in members from the pinned generated package.
pkg = (source / "src/soc_ifc/rtl/soc_ifc_reg_pkg.sv").read_text()
match = re.search(r"typedef struct packed\{([^{}]*)\} soc_ifc_reg__in_t;", pkg)
if not match:
    raise SystemExit("hwif_in type declaration changed")
fields = re.findall(r"\b([A-Za-z_]\w*)\s*;", match.group(1))
if len(fields) < 50 or len(fields) != len(set(fields)):
    raise SystemExit("hwif_in member extraction failed")
field_reports = "\n".join(
    f'      if ($isunknown(hwif_in.{field})) $display("DIAG_SOC field={field} value=%h", hwif_in.{field});'
    for field in fields
)

probes = {
    "src/riscv_core/veer_el2/rtl/dec/el2_dec_tlu_ctl.sv": (
        "  assert_flush_while_fastint: assert #0 (~((take_ext_int_start_d1 | take_ext_int_start_d2) & dec_tlu_flush_lower_r)) else $display(\"ERROR: TLU Flushing inside fast interrupt procedure!\");",
        """  bit diag_tlu_once = 0;
  always @(take_ext_int_start_d1 or take_ext_int_start_d2 or dec_tlu_flush_lower_r) begin
    #0;
    if (!diag_tlu_once && rst_l === 1'b1 &&
        (~((take_ext_int_start_d1 | take_ext_int_start_d2) & dec_tlu_flush_lower_r)) !== 1'b1) begin
      diag_tlu_once = 1;
      $display("DIAG_TLU t=%0t start=%b d1=%b d2=%b flush=%b ext_ready=%b blocked=%b mstatus=%h mie=%h",
               $time, take_ext_int_start, take_ext_int_start_d1, take_ext_int_start_d2,
               dec_tlu_flush_lower_r, ext_int_ready, block_interrupts, mstatus, mie);
    end
  end
""",
    ),
    "src/soc_ifc/rtl/soc_ifc_reg.sv": (
        "`CALIPTRA_ASSERT_KNOWN(ERR_HWIF_IN, hwif_in, clk, !hwif_in.cptra_pwrgood)",
        """bit diag_soc_once = 0;
always @(posedge clk) begin
  if (!diag_soc_once && hwif_in.cptra_pwrgood === 1'b1 && $isunknown(hwif_in)) begin
    diag_soc_once = 1;
    $display("DIAG_SOC t=%0t pwrgood=%b hwif_in=%h", $time, hwif_in.cptra_pwrgood, hwif_in);
""" + field_reports + "\n  end\nend\n",
    ),
    "src/riscv_core/veer_el2/rtl/lsu/el2_lsu_stbuf.sv": (
        "   assert_stbuf_overflow: assert #0 (stbuf_specvld_any[2:0] <= DEPTH);",
        """   bit diag_stbuf_once = 0;
   always @(stbuf_specvld_any) begin
      #0;
      if (!diag_stbuf_once && rst_l === 1'b1 && (stbuf_specvld_any[2:0] <= DEPTH) !== 1'b1) begin
         diag_stbuf_once = 1;
         $display("DIAG_STBUF t=%0t depth=%0d valid=%b committed=%0d spec_m=%0d spec_r=%0d total=%0d dual_m=%b dual_r=%b dccm_m=%b dccm_r=%b",
                  $time, DEPTH, stbuf_vld, stbuf_numvld_any, stbuf_specvld_m,
                  stbuf_specvld_r, stbuf_specvld_any, ldst_dual_m, ldst_dual_r,
                  isdccmst_m, isdccmst_r);
      end
   end
""",
    ),
}

# Check all substitutions before writing anything.
rewrites = {}
new_profile = reset_profile.read_bytes()
for name, (anchor, probe) in probes.items():
    data = (source / name).read_text()
    if data.count(anchor) != 1:
        raise SystemExit(f"probe anchor changed: {name}")
    rewrites[name] = data.replace(anchor, probe + anchor, 1)
    entry = ("${CALIPTRA_ROOT}/" + name).encode()
    if new_profile.count(entry) != 1:
        raise SystemExit(f"filelist entry missing or duplicated: {name}")
    new_profile = new_profile.replace(entry, str(output / "source" / Path(name).name).encode(), 1)

output.mkdir(parents=True)
(output / "source").mkdir()
manifest = {"pinned_commit": "49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e",
            "input_profile": str(reset_profile), "input_profile_sha256": digest(reset_profile.read_bytes()),
            "reset_bfm": str(reset_bfm), "reset_bfm_sha256": digest(reset_bfm.read_bytes()),
            "source_sha256": paths, "copies": {}}
for name, data in rewrites.items():
    dest = output / "source" / Path(name).name
    dest.write_text(data)
    manifest["copies"][name] = {"path": str(dest), "sha256": digest(dest.read_bytes())}
profile = output / "caliptra_top_tb_icarus_profile.vf"
profile.write_bytes(new_profile)
manifest["profile"] = str(profile)
manifest["profile_sha256"] = digest(new_profile)
(output / "overlay.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(profile)
