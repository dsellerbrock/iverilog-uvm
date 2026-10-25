class class_nettype_resolver;
  static function automatic logic [7:0] merge(input logic [7:0] drivers[]);
    merge = 0;
    foreach (drivers[i]) merge |= drivers[i];
  endfunction
endclass

nettype logic [7:0] class_resolved_byte with class_nettype_resolver::merge;

module sv_nettype_class_resolver;
  class_resolved_byte single;
  class_resolved_byte multiple;
  logic [7:0] one_driver;
  logic [7:0] left_driver;
  logic [7:0] right_driver;

  assign single = one_driver;
  assign multiple = left_driver;
  assign multiple = right_driver;

  initial begin
    one_driver = 8'h40;
    left_driver = 8'h05;
    right_driver = 8'h30;
    #1;
    if (single !== 8'h40) $fatal(1, "single driver: %h", single);
    if (multiple !== 8'h35) $fatal(1, "multiple drivers: %h", multiple);
    right_driver = 8'h82;
    #1;
    if (multiple !== 8'h87) $fatal(1, "updated multiple drivers: %h", multiple);
    $display("PASS: static class nettype resolver");
    $finish;
  end
endmodule
