#!/usr/bin/env python3
"""Extend the first copied-source probe with exact X-producing operands."""

from hashlib import sha256
from pathlib import Path
import json
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: prepare_second_probe.py FIRST_OVERLAY_DIR /tmp/NEW_OUTPUT_DIR")

first = Path(sys.argv[1]).resolve()
output = Path(sys.argv[2]).resolve()
source = Path(__file__).resolve().parents[3] / "caliptra-rtl"
if not output.is_relative_to(Path("/tmp").resolve()) or output.exists():
    raise SystemExit("output must be a new directory under /tmp")

def digest(data):
    return sha256(data).hexdigest()

expected = {
    first / "overlay.json": "c98ab2bd330fbd2125f490330d184fe2e56ef8608f1c9c28e9c6f81ad64b3170",
    first / "caliptra_top_tb_icarus_profile.vf": "ecafefba14a7737ca77e2402da2ad8d3aaca0a02630936b8f7d14b42d850002b",
    first / "source/el2_dec_tlu_ctl.sv": "592358609327da74196a1ee34350452380ab3aec758f00edb8a2c1a4cc9d2969",
    first / "source/soc_ifc_reg.sv": "69f4ff560168643a7d35b794fd66b4342326c8a416b5b85cf146a76a03666050",
    first / "source/el2_lsu_stbuf.sv": "15f62d52498af08d0659e99dde4f5de4244e05a842a75b8dce7a307b7d2bd053",
    source / "src/soc_ifc/rtl/soc_ifc_top.sv": "d27f7102c082b6b82f5469e7a2c3b6a380edcaffe44e605b9354f57e63e317fe",
}
for path, sha in expected.items():
    if digest(path.read_bytes()) != sha:
        raise SystemExit(f"input hash changed: {path}")

probes = {
    "el2_dec_tlu_ctl.sv": (
        "               dec_tlu_flush_lower_r, ext_int_ready, block_interrupts, mstatus, mie);",
        """
      $display("DIAG_TLU_INPUT csr_stall=%b mstatus_mie=%b meip=%b meie=%b lsu_fast_stall=%b sync_flush=%b intr_valid=%b mret=%b halt=%b reset=%b",
               dec_csr_stall_int_ff, mstatus_mie_ns, mip[MIP_MEIP], mie_ns[MIE_MEIE],
               lsu_fastint_stall_any, synchronous_flush_r, interrupt_valid_r,
               mret_r, take_halt, take_reset);""",
    ),
    "soc_ifc_reg.sv": (
        '      if ($isunknown(hwif_in.CPTRA_HW_ERROR_FATAL)) $display("DIAG_SOC field=CPTRA_HW_ERROR_FATAL value=%h", hwif_in.CPTRA_HW_ERROR_FATAL);',
        """
      $display("DIAG_SOC_ECC iccm_next=%b iccm_we=%b dccm_next=%b dccm_we=%b nmi_we=%b crypto_we=%b",
               hwif_in.CPTRA_HW_ERROR_FATAL.iccm_ecc_unc.next,
               hwif_in.CPTRA_HW_ERROR_FATAL.iccm_ecc_unc.we,
               hwif_in.CPTRA_HW_ERROR_FATAL.dccm_ecc_unc.next,
               hwif_in.CPTRA_HW_ERROR_FATAL.dccm_ecc_unc.we,
               hwif_in.CPTRA_HW_ERROR_FATAL.nmi_pin.we,
               hwif_in.CPTRA_HW_ERROR_FATAL.crypto_err.we);""",
    ),
    "el2_lsu_stbuf.sv": (
        "                  isdccmst_m, isdccmst_r);",
        """
         $display("DIAG_STBUF_M valid=%b store=%b dma=%b addr_dccm=%b dual=%b",
                  lsu_pkt_m.valid, lsu_pkt_m.store, lsu_pkt_m.dma,
                  addr_in_dccm_m, ldst_dual_m);""",
    ),
}

rewrites = {}
for name, (anchor, probe) in probes.items():
    data = (first / "source" / name).read_text()
    if data.count(anchor) != 1:
        raise SystemExit(f"probe anchor changed: {name}")
    rewrites[name] = data.replace(anchor, anchor + probe, 1)

soc_top = (source / "src/soc_ifc/rtl/soc_ifc_top.sv").read_text()
anchor = "always_comb soc_ifc_reg_hwif_in.CPTRA_HW_ERROR_FATAL.crypto_err  .we = crypto_error;"
if soc_top.count(anchor) != 1:
    raise SystemExit("SOC IFC source anchor changed")
monitor = """bit diag_soc_inputs_once = 0;
always @(posedge clk) begin
  if (!diag_soc_inputs_once && cptra_pwrgood === 1'b1 &&
      $isunknown(soc_ifc_reg_hwif_in.CPTRA_HW_ERROR_FATAL)) begin
    diag_soc_inputs_once = 1;
    $display("DIAG_SOC_INPUT t=%0t iccm_ecc=%b dccm_ecc=%b fw_window=%b iccm_we=%b dccm_we=%b",
             $time, rv_ecc_sts.cptra_iccm_ecc_double_error,
             rv_ecc_sts.cptra_dccm_ecc_double_error, fw_update_rst_window,
             soc_ifc_reg_hwif_in.CPTRA_HW_ERROR_FATAL.iccm_ecc_unc.we,
             soc_ifc_reg_hwif_in.CPTRA_HW_ERROR_FATAL.dccm_ecc_unc.we);
  end
end
"""
rewrites["soc_ifc_top.sv"] = soc_top.replace(anchor, monitor + anchor, 1)

profile = (first / "caliptra_top_tb_icarus_profile.vf").read_bytes()
entries = {
    "el2_dec_tlu_ctl.sv": first / "source/el2_dec_tlu_ctl.sv",
    "soc_ifc_reg.sv": first / "source/soc_ifc_reg.sv",
    "el2_lsu_stbuf.sv": first / "source/el2_lsu_stbuf.sv",
    "soc_ifc_top.sv": Path("${CALIPTRA_ROOT}/src/soc_ifc/rtl/soc_ifc_top.sv"),
}
for name, old in entries.items():
    token = str(old).encode()
    if profile.count(token) != 1:
        raise SystemExit(f"filelist entry changed: {name}")
    profile = profile.replace(token, str(output / "source" / name).encode(), 1)

output.mkdir(parents=True)
(output / "source").mkdir()
copies = {}
for name, data in rewrites.items():
    path = output / "source" / name
    path.write_text(data)
    copies[name] = {"path": str(path), "sha256": digest(path.read_bytes())}
profile_path = output / "caliptra_top_tb_icarus_profile.vf"
profile_path.write_bytes(profile)
(output / "overlay.json").write_text(json.dumps({
    "first_overlay": str(first), "first_overlay_sha256": expected[first / "overlay.json"],
    "profile": str(profile_path), "profile_sha256": digest(profile), "copies": copies,
}, indent=2) + "\n")
print(profile_path)
