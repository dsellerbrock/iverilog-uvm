class issue435_boundary_resolver;
  static function logic resolve(input logic drivers[]);
    logic value;
    value = 1'b0;
    foreach (drivers[i]) value |= drivers[i];
    return value;
  endfunction
endclass

nettype logic issue435_boundary_net with issue435_boundary_resolver::resolve;
module issue435_class_resolver_boundary;
  issue435_boundary_net net;
  logic driver;
  assign net = driver;
  initial begin
    driver = 1'b0; #1;
    if (net !== 1'b0) $fatal(1, "single-driver zero mismatch");
    driver = 1'b1; #1;
    if (net !== 1'b1) $fatal(1, "single-driver one mismatch");
    $display("PASSED");
  end
endmodule
