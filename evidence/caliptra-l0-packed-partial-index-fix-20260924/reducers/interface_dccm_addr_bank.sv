// Reduced from pinned Caliptra v2.1.2: el2_mem_if.sv:46 (logic [N-1:0][17:4] dccm_addr_bank),
// el2_lsu_dccm_mem.sv:104-108 (per-bank always_comb export), el2_mem.sv:113 (whole-member assign),
// caliptra_veer_sram_export.sv:143-145 (.ADR(el2_mem_export.dccm_addr_bank[i])).
interface mif;
  logic [3:0][17:4] a;
  modport src (output a);
  modport sink(input a);
endinterface
module ram(input logic [13:0] ADR, output logic [13:0] seen);
  assign seen = ADR;
endmodule
module src(mif.src e);
  logic [3:0][17:4] local_a;
  for (genvar i = 0; i < 4; i++) begin : g
    assign local_a[i][4+:14] = 14'h2000 + 14'(i);
    always_comb begin
      e.a[i] = local_a[i];
    end
  end
endmodule
module t;
  mif loc(); mif ext();
  src s(.e(loc));
  assign ext.a = loc.a;
  logic [13:0] seen [4];
  for (genvar i = 0; i < 4; i++) begin : sink
    ram r(.ADR(ext.a[i]), .seen(seen[i]));
  end
  logic [13:0] direct3; assign direct3 = ext.a[3];
  initial begin
    #1;
    $display("loc.a=%h ext.a=%h", loc.a, ext.a);
    $display("direct ext.a[3]=%h loc.a[3]=%h", direct3, loc.a[3]);
    for (int k = 0; k < 4; k++) $display("port ADR[%0d]=%h expected=%h", k, seen[k], 14'h2000 + 14'(k));
    if (seen[0] === 14'h2000 && seen[1] === 14'h2001 && seen[2] === 14'h2002 && seen[3] === 14'h2003 && direct3 === 14'h2003)
      $display("RESULT GREEN"); else $display("RESULT RED");
  end
endmodule
