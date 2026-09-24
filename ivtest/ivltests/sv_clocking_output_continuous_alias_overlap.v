interface clocking_alias_overlap_if(input logic clk);
  logic source, final_value;
  assign final_value = source;
  clocking sender_cb @(posedge clk);
    output alias_sig = final_value;
  endclocking
  modport DRIVER(clocking sender_cb);
endinterface

class alias_overlap_driver;
  virtual clocking_alias_overlap_if.DRIVER vif;
  task run();
    vif.sender_cb.alias_sig <= 1'b1;
  endtask
endclass

module sv_clocking_output_continuous_alias_overlap;
  logic clk;
  clocking_alias_overlap_if bus(clk);
  alias_overlap_driver d;
  initial begin
    d = new();
    d.vif = bus;
    d.run();
  end
endmodule
