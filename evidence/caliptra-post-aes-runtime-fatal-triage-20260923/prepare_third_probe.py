#!/usr/bin/env python3
"""Add bounded PIC, IFU, and LSU X-origin displays to the second overlay."""

from hashlib import sha256
from pathlib import Path
import json
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: prepare_third_probe.py SECOND_OVERLAY_DIR /tmp/NEW_OUTPUT_DIR")

second = Path(sys.argv[1]).resolve()
output = Path(sys.argv[2]).resolve()
source = Path(__file__).resolve().parents[3] / "caliptra-rtl"
if not output.is_relative_to(Path("/tmp").resolve()) or output.exists():
    raise SystemExit("output must be a new directory under /tmp")

def digest(data):
    return sha256(data).hexdigest()

expected = {
    second / "overlay.json": "5b83605e00dd1c66999152658429f7be2869ba8bacec80dad534b139005af3f8",
    second / "caliptra_top_tb_icarus_profile.vf": "44122cc02f7c6a3be10af54ef99e780a9f62676ea91ae6eece0ca63ff37d6ab1",
    second / "source/el2_dec_tlu_ctl.sv": "c3179b73d95c0865cb44f674a222b273255cbce8a7d31abd8917671fcd922139",
    second / "source/soc_ifc_reg.sv": "55ef307e454aedefe42a6633153190abf8384b694fa90b86c04b4d82c0e0ff32",
    second / "source/el2_lsu_stbuf.sv": "8e1c66c7c2d868e45ffdcd1e7c82bb7b8983a951103707b4f4758546263a999d",
    second / "source/soc_ifc_top.sv": "76a7f98e14222b5676715ff5eba7ddca7b454c0adbd8336c3eb43c661d740408",
    source / "src/riscv_core/veer_el2/rtl/el2_pic_ctrl.sv": "464828f55de8a6fdc178a54f16ef7cc7721a5974d9ba0d159e55cfd0bcad0f15",
    source / "src/riscv_core/veer_el2/rtl/ifu/el2_ifu_mem_ctl.sv": "20823faba6a4f721f1a4e713a318a9095e076b961ce3423dabd0ebcc47abaaa7",
    source / "src/riscv_core/veer_el2/rtl/lsu/el2_lsu_lsc_ctl.sv": "df2b2ff5c14742d40e67becc6b3f2043e2bf9b987edfac6406cfa384543e0109",
}
for path, sha in expected.items():
    if digest(path.read_bytes()) != sha:
        raise SystemExit(f"input hash changed: {path}")

probes = {
    "el2_pic_ctrl.sv": (
        "rvdff #(1) mexintpend_ff  (.*, .clk(free_clk), .din (mexintpend_in), .dout(mexintpend));",
        """
bit diag_pic_x_once = 0;
always @(posedge free_clk) begin : diag_pic_first_x
    int first_x;
    int count_x;
    if (!diag_pic_x_once && rst_l === 1'b1 && $time >= 43800 && $time <= 43870 &&
        $isunknown({mexintpend, mexintpend_in, selected_int_priority, meipt_inv, meicurpl_inv})) begin
        diag_pic_x_once = 1;
        first_x = -1;
        count_x = 0;
        for (int k = 0; k < pt.PIC_TOTAL_INT_PLUS1; k++) begin
            if ($isunknown(intpend_w_prior_en[k])) begin
                if (first_x < 0) first_x = k;
                count_x++;
            end
        end
        $display("DIAG_PIC_X t=%0t pending=%b pending_in=%b priority=%h threshold=%h current=%h invert=%b x_sources=%0d first=%0d",
                 $time, mexintpend, mexintpend_in, selected_int_priority,
                 meipt_inv, meicurpl_inv, intpriord, count_x, first_x);
        if (first_x >= 0)
            $display("DIAG_PIC_SOURCE index=%0d raw=%b gateway=%b enabled=%b priority=%h qualified=%h",
                     first_x, extintsrc_req[first_x], extintsrc_req_gw[first_x],
                     intenable_reg[first_x], intpriority_reg[first_x], intpend_w_prior_en[first_x]);
    end
end
""",
    ),
    "el2_ifu_mem_ctl.sv": (
        "                                                                   ({iccm_double_ecc_error[1], iccm_double_ecc_error[0]} ) & {2{ifc_iccm_access_f}} ;",
        """
  bit diag_ifu_x_once = 0;
  always @(posedge free_l2clk) begin
    if (!diag_ifu_x_once && rst_l === 1'b1 && $time >= 43800 && $time <= 43870 &&
        $isunknown({iccm_rd_ecc_double_err, iccm_dma_rd_ecc_double_err})) begin
      diag_ifu_x_once = 1;
      $display("DIAG_IFU_X t=%0t fetch_ecc=%b dma_ecc=%b access=%b fetch_req=%b addr_bit1=%b word_enable=%b decoded=%b dma_valid=%b dma_error=%b",
               $time, iccm_rd_ecc_double_err, iccm_dma_rd_ecc_double_err,
               ifc_iccm_access_f, ifc_fetch_req_f, ifu_fetch_addr_int_f[1],
               iccm_ecc_word_enable, iccm_double_ecc_error, iccm_dma_rvalid,
               iccm_dma_ecc_error);
    end
  end
""",
    ),
    "el2_lsu_lsc_ctl.sv": (
        "   rvdff #($bits(el2_lsu_pkt_t)-1) lsu_pkt_rff (.*, .din(lsu_pkt_r_in[$bits(el2_lsu_pkt_t)-1:1]), .dout(lsu_pkt_r[$bits(el2_lsu_pkt_t)-1:1]), .clk(lsu_c1_r_clk));",
        """
   bit diag_lsu_x_once = 0;
   always @(posedge clk) begin
      if (!diag_lsu_x_once && rst_l === 1'b1 && $time >= 43800 && $time <= 43870 &&
          $isunknown(lsu_pkt_m)) begin
         diag_lsu_x_once = 1;
         $display("DIAG_LSU_X t=%0t m=%h m_in=%h d=%h decode=%h dma=%h decode_sel=%b dma_req=%b flush=%b c1_m=%b c2_m=%b addr=%b end=%b addr_dccm=%b",
                  $time, lsu_pkt_m, lsu_pkt_m_in, lsu_pkt_d, lsu_p, dma_pkt_d,
                  dec_lsu_valid_raw_d, dma_dccm_req, flush_m_up, lsu_c1_m_clk,
                  lsu_c2_m_clk, lsu_addr_m[2], end_addr_m[2], addr_in_dccm_m);
      end
   end
""",
    ),
}

paths = {
    "el2_pic_ctrl.sv": source / "src/riscv_core/veer_el2/rtl/el2_pic_ctrl.sv",
    "el2_ifu_mem_ctl.sv": source / "src/riscv_core/veer_el2/rtl/ifu/el2_ifu_mem_ctl.sv",
    "el2_lsu_lsc_ctl.sv": source / "src/riscv_core/veer_el2/rtl/lsu/el2_lsu_lsc_ctl.sv",
}
rewrites = {}
profile = (second / "caliptra_top_tb_icarus_profile.vf").read_bytes()
for name, path in paths.items():
    data = path.read_text()
    anchor, probe = probes[name]
    if data.count(anchor) != 1:
        raise SystemExit(f"probe anchor changed: {name}")
    rewrites[name] = data.replace(anchor, anchor + probe, 1)
    token = ("${CALIPTRA_ROOT}/" + str(path.relative_to(source))).encode()
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
    "second_overlay": str(second), "second_overlay_sha256": expected[second / "overlay.json"],
    "profile": str(profile_path), "profile_sha256": digest(profile), "copies": copies,
}, indent=2) + "\n")
print(profile_path)
