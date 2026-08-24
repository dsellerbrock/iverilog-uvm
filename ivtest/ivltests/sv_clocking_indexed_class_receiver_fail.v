// This drive is legal SystemVerilog, but safely lowering it requires the
// indexed class-property receiver to be evaluated and captured exactly once.
// Icarus rejects the boundary until that captured-receiver lowering exists.
interface clocking_indexed_receiver_if(input logic clk);
  logic raw;

  clocking cb @(posedge clk);
    output raw;
  endclocking
endinterface

class clocking_indexed_receiver_leaf;
  virtual clocking_indexed_receiver_if vif;
endclass

class clocking_indexed_receiver_root;
  clocking_indexed_receiver_leaf leaves[2];
endclass

module sv_clocking_indexed_class_receiver_fail;
  logic clk;
  clocking_indexed_receiver_if bus(clk);
  clocking_indexed_receiver_root root;
  int index = 1;

  initial begin
    root = new;
    root.leaves[index] = new;
    root.leaves[index].vif = bus;
    root.leaves[index].vif.cb.raw <= 1'b1;
  end
endmodule
