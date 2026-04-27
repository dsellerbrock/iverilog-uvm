// Minimal probe: what errors does virtual interface in a class produce today?
interface simple_if;
  logic clk;
  logic [7:0] data;
  logic valid;
endinterface

class my_driver;
  virtual simple_if vif;  // <-- the key line

  function void set_if(virtual simple_if i);
    vif = i;
  endfunction

  task drive(logic [7:0] d);
    @(posedge vif.clk);
    vif.data  = d;
    vif.valid = 1;
  endtask
endclass

module top;
  simple_if dut_if();
  initial begin
    dut_if.clk   = 0;
    forever #5 dut_if.clk = ~dut_if.clk;
  end

  initial begin
    my_driver drv = new();
    drv.set_if(dut_if);
    drv.drive(8'hAB);
    #20;
    $display("data=%0h valid=%0b", dut_if.data, dut_if.valid);
    $finish;
  end
endmodule
