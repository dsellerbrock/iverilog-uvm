module issue2905_clocking_output_concat;
  logic clk = 0;
  logic [3:0] single = 4'b1000, parts = 0;
  logic [1:0] left = 0, right = 0;
  logic a = 1, b = 0;
  clocking cb @(posedge clk);
    input ip = {a, b};
    output one = {single[1:0]};
    output two = {parts[1:0], parts[3:2]};
    output vars = {left, right};
  endclocking
  always #5 clk = ~clk;
  initial begin
    @(cb);
    if (cb.ip !== 2'b10) $fatal(1, "input concat: %b", cb.ip);
    cb.one <= 2'b01;
    cb.two <= 4'b1011;
    cb.vars <= 4'b0110;
    @(cb); #1;
    if (single !== 4'b1001 || parts !== 4'b1110 ||
        left !== 2'b01 || right !== 2'b10)
      $fatal(1, "outputs: %b %b %b %b", single, parts, left, right);
    cb.one <= 2'b10;
    cb.two <= 4'b0100;
    cb.vars <= 4'b1001;
    @(cb); #1;
    if (single !== 4'b1010 || parts !== 4'b0001 ||
        left !== 2'b10 || right !== 2'b01)
      $fatal(1, "updated outputs: %b %b %b %b", single, parts, left, right);
    cb.vars <= 4'b1x0z;
    @(cb); #1;
    if (left !== 2'b1x || right !== 2'b0z)
      $fatal(1, "four-state outputs: %b %b", left, right);
    $display("issue2905 clocking output concatenations passed");
    $finish;
  end
endmodule
