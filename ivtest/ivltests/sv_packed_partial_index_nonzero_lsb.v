// A partial index chain on a multi-dimensional packed vector selects a
// whole sub-slice. IEEE 1800-2017/2023 7.4.5: m[i] of logic [3:0][17:4] m
// is the 14-bit element whose first bit is m[i][4], not m[i][0].
// Reduced from Caliptra v2.1.2 el2_mem_if.sv:46 (dccm_addr_bank), written
// per bank from an always_comb through a modport (el2_lsu_dccm_mem.sv:104).
interface pk_if;
  logic [3:0][17:4] desc;      // nonzero inner LSB (the Caliptra shape)
  logic [1:0][4:11] asc;       // ascending inner range
  logic [1:0][3:-4] neg;       // negative inner LSB
  logic [1:0][2:1][7:4] cube;  // two trailing dimensions
  modport src(output desc, output asc, output neg, output cube);
endinterface

module pk_writer(pk_if.src e);
  logic [13:0] rd_desc3;
  logic [7:0] rd_cube1;
  logic [27:0] rd_part, rd_idx_up;
  for (genvar i = 0; i < 4; i++) begin : g
    always_comb e.desc[i] = 14'h2000 + 14'(i);
  end
  // Read back through the modport: partial chains and outer part-selects.
  always_comb rd_desc3 = e.desc[3];
  always_comb rd_cube1 = e.cube[1];
  always_comb rd_part = e.desc[2:1];
  always_comb rd_idx_up = e.desc[1 +: 2];
  initial begin
    e.asc[1] = 8'hA5;
    e.asc[0] = 8'h3C;
    e.neg[1] = 8'h81;
    e.neg[0] = 8'h7E;
    e.cube[1] = 8'h96;           // two padded dimensions
    e.cube[0][2] = 4'h5;         // one padded dimension
    e.cube[0][1] = 4'hA;
  end
endmodule

class pk_holder;
  logic [3:0][7:4] p;
endclass

module pk_sink(input logic [13:0] adr, output logic [13:0] seen);
  assign seen = adr;
endmodule

module test;
  pk_if ifc();
  pk_writer w(.e(ifc));
  logic [13:0] seen [4];
  for (genvar i = 0; i < 4; i++) begin : sink
    pk_sink s(.adr(ifc.desc[i]), .seen(seen[i]));
  end

  typedef struct packed { logic [1:0][7:4] f; logic [3:0] tag; } pk_s;
  pk_s st;
  pk_holder h;
  bit failed = 0;
  int k;

  task automatic check(string what, logic [63:0] got, logic [63:0] want);
    if (got !== want) begin
      $display("FAILED %s: got %h want %h", what, got, want);
      failed = 1;
    end
  endtask

  initial begin
    h = new;
    h.p = '0;
    h.p[2] = 4'h9;
    st = '0;
    st.f[1] = 4'hC;
    k = 1;
    h.p[k] = 4'h3;               // run-time index on a class property
    #1;
    check("modport read desc[3]", w.rd_desc3, 14'h2003);
    check("modport read cube[1]", w.rd_cube1, 8'h96);
    check("modport read desc[2:1]", w.rd_part, {14'h2002, 14'h2001});
    check("modport read desc[1+:2]", w.rd_idx_up, {14'h2002, 14'h2001});
    check("class property read p[2]", h.p[2], 4'h9);
    check("class property read p[k]", h.p[k], 4'h3);
    check("struct member read f[1]", st.f[1], 4'hC);
    check("struct member read f[0]", st.f[0], 4'h0);
    h.p = '0;
    h.p[2] = 4'h9;
    check("desc flat", ifc.desc, 56'h800e0028006000);
    for (int k = 0; k < 4; k++)
      check($sformatf("desc port[%0d]", k), seen[k], 14'h2000 + 14'(k));
    check("asc flat", ifc.asc, 16'hA53C);
    check("neg flat", ifc.neg, 16'h817E);
    check("cube flat", ifc.cube, 16'h965A);
    check("class property", h.p, 16'h0900);
    check("struct member", st, 12'hC00);
    if (!failed) $display("PASSED");
  end
endmodule
