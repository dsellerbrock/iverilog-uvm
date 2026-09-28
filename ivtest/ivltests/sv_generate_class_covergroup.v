// A generate iteration owns its class type and the signals sampled by its
// standalone covergroup (IEEE 1800-2017/2023 27 and 19.3).
interface cg_if(input logic clk);
  for (genvar i = 0; i < 2; i++) begin : g
    int value;
    class C;
      function int id();
        return i;
      endfunction
    endclass
    C obj = new;
    covergroup cg @(posedge clk);
      cp: coverpoint value { bins own = {i}; }
    endgroup
    cg cg_inst = new;
    initial value = i;
  end
endinterface

module top;
  logic clk = 0;
  cg_if ci(clk);
  initial begin
    #1 clk = 1;
    #1;
    if (ci.g[0].cg_inst.get_inst_coverage() != 100.0) $fatal(1, "g0 coverage");
    if (ci.g[1].cg_inst.get_inst_coverage() != 100.0) $fatal(1, "g1 coverage");
    if (ci.g[0].obj.id() != 0 || ci.g[1].obj.id() != 1) $fatal(1, "class identity");
    $display("PASSED");
  end
endmodule
