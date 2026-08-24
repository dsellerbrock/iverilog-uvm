// This drive is legal SystemVerilog, but safely lowering it requires the root
// indexed class receiver to be evaluated and captured exactly once. Icarus
// rejects the boundary without executing the stateful selector.
interface clocking_root_indexed_receiver_if(input logic clk);
  logic raw;

  clocking cb @(posedge clk);
    output raw;
  endclocking
endinterface

class clocking_root_indexed_receiver;
  virtual clocking_root_indexed_receiver_if vif;
endclass

module sv_clocking_root_indexed_class_receiver_fail;
  logic clk;
  clocking_root_indexed_receiver_if bus(clk);
  clocking_root_indexed_receiver roots[2];
  int selector_calls;

  function automatic int choose();
    selector_calls += 1;
    return 0;
  endfunction

  initial begin
    roots[0] = new;
    roots[0].vif = bus;
    roots[choose()].vif.cb.raw <= 1'b1;
  end
endmodule
