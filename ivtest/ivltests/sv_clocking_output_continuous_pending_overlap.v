interface clocking_pending_overlap_if(input logic clk);
  logic source, final_value;
  assign final_value = source;
  clocking sender_cb @(posedge clk);
    output final_value;
  endclocking
endinterface

class pending_overlap_driver;
  virtual clocking_pending_overlap_if vif;
  task run();
    vif.\_ivl_opend$sender_cb$final_value = 1'b1;
  endtask
endclass

module sv_clocking_output_continuous_pending_overlap;
  logic clk;
  clocking_pending_overlap_if bus(clk);
  pending_overlap_driver d;
  initial begin
    d = new();
    d.vif = bus;
    d.run();
  end
endmodule
