// Virtual interface smoke test — test @(posedge vif.clk) and property writes
interface counter_if(input logic clk);
  logic [7:0] count;
  logic       reset;
endinterface

class vif_user;
  virtual counter_if vif;

  task drive();
    @(posedge vif.clk);
    vif.reset <= 1'b0;
    vif.count <= 8'hAA;
  endtask

  function bit check_reset();
    return (vif.reset === 1'b1);
  endfunction
endclass

module top;
  logic clk = 0;
  always #5 clk = ~clk;

  counter_if dut_if(.clk(clk));
  vif_user   usr;

  initial begin
    usr = new();
    usr.vif = dut_if;

    dut_if.reset = 1;
    @(posedge clk);
    if (usr.check_reset())
      $display("PASS: reset is asserted");
    else
      $display("FAIL: reset not asserted");

    // Call drive() to test @(posedge vif.clk) and VIF property writes
    usr.drive();
    $display("PASS: drive() completed, count=%0d reset=%0b", dut_if.count, dut_if.reset);
    $finish;
  end
endmodule
