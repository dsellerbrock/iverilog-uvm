class issue435_resolver;
  static function logic resolve(input logic drivers[]);
    logic value;
    value = 1'b0;
    foreach (drivers[i]) value |= drivers[i];
    return value;
  endfunction
endclass

nettype logic issue435_net with issue435_resolver::resolve;

module issue435_class_resolver;
  issue435_net net;
  logic a, b;
  assign net = a;
  assign net = b;

  initial begin
    a = 1'b0; b = 1'b0; #1;
    if (net !== 1'b0) $fatal(1, "00 resolution mismatch");
    a = 1'b1; #1;
    if (net !== 1'b1) $fatal(1, "10 resolution mismatch");
    a = 1'b0; b = 1'b1; #1;
    if (net !== 1'b1) $fatal(1, "01 resolution mismatch");
    a = 1'b1; b = 1'b0; #1;
    $display("PASSED");
  end
endmodule
