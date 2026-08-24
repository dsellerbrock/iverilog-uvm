// A virtual-interface clocking input must have the same sampled value when
// passed directly to a system task as it has in an ordinary expression.
`timescale 1ns/1ps

interface sys_task_arg_if(input logic clk);
  logic raw;

  clocking cb @(posedge clk);
    input #2 raw;
  endclocking
endinterface

module sv_clocking_vif_input_sys_task_arg;
  logic clk = 1'b0;
  sys_task_arg_if bus(clk);
  virtual sys_task_arg_if vif;
  logic sampled;
  string rendered;

  always #5 clk = ~clk;

  initial begin
    bus.raw = 1'b0;
    #1 bus.raw = 1'b1;
    #3 bus.raw = 1'b0;
  end

  initial begin
    vif = bus;
    @(vif.cb);
    sampled = vif.cb.raw;
    if (sampled !== 1'b1 || vif.cb.raw !== 1'b1)
      $fatal(1, "ordinary clocking read is stale: copy=%b direct=%b",
             sampled, vif.cb.raw);
    rendered = $sformatf("%b", vif.cb.raw);
    if (rendered != "1")
      $fatal(1, "system-function clocking read is stale: %s", rendered);
    $display("sampled=%b direct=%b", sampled, vif.cb.raw);
    $display("PASSED");
    $finish;
  end
endmodule
