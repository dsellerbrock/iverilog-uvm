// A static cross has one logical bin in each dimension, but every source bin
// has 16 disjoint ranges. The predicate Cartesian product is 16**16 == 2**64:
// it must hit the explicit implementation guard rather than wrapping to zero.
module top;
  int v0, v1, v2, v3, v4, v5, v6, v7;
  int v8, v9, va, vb, vc, vd, ve, vf;

  covergroup cg;
    cp0: coverpoint v0 { bins many = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}; }
    cp1: coverpoint v1 { bins many = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}; }
    cp2: coverpoint v2 { bins many = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}; }
    cp3: coverpoint v3 { bins many = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}; }
    cp4: coverpoint v4 { bins many = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}; }
    cp5: coverpoint v5 { bins many = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}; }
    cp6: coverpoint v6 { bins many = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}; }
    cp7: coverpoint v7 { bins many = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}; }
    cp8: coverpoint v8 { bins many = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}; }
    cp9: coverpoint v9 { bins many = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}; }
    cpa: coverpoint va { bins many = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}; }
    cpb: coverpoint vb { bins many = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}; }
    cpc: coverpoint vc { bins many = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}; }
    cpd: coverpoint vd { bins many = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}; }
    cpe: coverpoint ve { bins many = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}; }
    cpf: coverpoint vf { bins many = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}; }
    all: cross cp0, cp1, cp2, cp3, cp4, cp5, cp6, cp7,
               cp8, cp9, cpa, cpb, cpc, cpd, cpe, cpf;
  endgroup

  cg cov = new;
  initial begin
    $display("PASSED");
    $finish;
  end
endmodule
