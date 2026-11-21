// IEEE 1800-2017/2023 13.4.4: a continuous assignment cannot defer a drive.
module issue3741_clocking_fail;
  logic clk = 0;
  logic target = 0;
  logic data = 1;
  clocking cb @(posedge clk);
    output target;
  endclocking
  function integer schedule();
    cb.target <= data;
    return 1;
  endfunction
  wire unused = schedule();
  initial begin
    #1 clk = 1;
    #2 $display("UNEXPECTED");
  end
endmodule
