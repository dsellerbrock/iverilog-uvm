module neighbor(
  input logic value,
  inout wire shared,
  output wire mirror
);
  assign mirror = value;
  assign shared = value ? 1'bz : 1'b0;
endmodule

module test;
  logic value;
  logic external_active;
  tri shared;
  wire mirror;
  assign shared = external_active ? 1'b1 : 1'bz;
  neighbor dut(value, shared, mirror);
  initial begin
    value = 1;
    external_active = 0;
    #1;
    if (mirror !== 1 || shared !== 1'bz) $fatal(1, "floating neighbor");
    external_active = 1;
    #1;
    if (shared !== 1) $fatal(1, "external inout drive");
    value = 0;
    #1;
    if (mirror !== 0 || shared !== 1'bx) $fatal(1, "inout resolution");
    external_active = 0;
    #1;
    if (shared !== 0) $fatal(1, "inout release");
    $display("PASS input/inout neighbors");
  end
endmodule
