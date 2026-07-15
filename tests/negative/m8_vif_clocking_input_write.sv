// M8-2a-4 negative: writing an input clockvar through a virtual
// interface must be a compile error (IEEE 1800-2017 14.3).
// EXPECT-FAIL-COMPILE
interface m8n_bus_if(input logic clk);
  logic [7:0] din;
  clocking cb @(posedge clk);
    input din;
  endclocking
endinterface

class m8n_drv;
  virtual m8n_bus_if vif;
  task poke;
    vif.cb.din <= 8'hff;   // error: cannot drive an input clockvar
  endtask
endclass

module m8_vif_clocking_input_write;
  logic clk = 0;
  m8n_bus_if bif(clk);
  m8n_drv d;
  initial begin
    d = new;
    d.vif = bif;
    d.poke();
  end
endmodule
