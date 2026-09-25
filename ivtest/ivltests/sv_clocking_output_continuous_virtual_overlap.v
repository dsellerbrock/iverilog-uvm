interface clocking_virtual_overlap_if(input logic clk);
  logic source, final_value;
  assign final_value = source;
  clocking sender_cb @(posedge clk);
    output final_value;
  endclocking
endinterface

class virtual_overlap_driver;
  virtual clocking_virtual_overlap_if vif;
  task run();
    vif.sender_cb.final_value <= 1'b1;
  endtask
endclass

module sv_clocking_output_continuous_virtual_overlap;
  logic clk;
  clocking_virtual_overlap_if bus(clk);
  virtual_overlap_driver d;
  initial begin
    d = new();
    d.vif = bus;
    d.run();
  end
endmodule
