// Test @(negedge vif.clk) and @(vif.clk) (anyedge) for virtual interface members
interface simple_if;
  logic clk;
  logic [7:0] data;
endinterface

class my_driver;
  virtual simple_if vif;

  function void set_if(virtual simple_if i);
    vif = i;
  endfunction

  task drive_negedge(logic [7:0] d);
    @(negedge vif.clk);
    vif.data = d;
  endtask

  task drive_anyedge(logic [7:0] d);
    @(vif.clk);
    vif.data = d;
  endtask
endclass

module top;
  simple_if dut_if();
  integer clk_count = 0;

  initial begin
    dut_if.clk = 0;
    forever #5 dut_if.clk = ~dut_if.clk;
  end

  initial begin
    my_driver drv = new();
    drv.set_if(dut_if);

    // Test negedge: wait for falling edge, set data=0xCD
    drv.drive_negedge(8'hCD);
    $display("negedge: data=%0h (expect cd)", dut_if.data);

    // Test anyedge: wait for any edge (next clock transition), set data=0xEF
    drv.drive_anyedge(8'hEF);
    $display("anyedge: data=%0h (expect ef)", dut_if.data);

    #20;
    $finish;
  end
endmodule
