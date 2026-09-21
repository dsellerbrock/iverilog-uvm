module string_synthesis_boundary(
  input logic [7:0] source,
  output logic [7:0] result
);
  string sink;
  assign sink = string'(source);
  always_comb result = sink.getc(0);
endmodule

module test;
  logic [7:0] source;
  logic [7:0] result;
  string_synthesis_boundary dut(.*);

  initial begin
    source = "A";
    #1;
    if (result != "A") $fatal(1, "initial observable value: %h", result);
    source = "Z";
    #1;
    if (result != "Z") $fatal(1, "updated observable value: %h", result);
    $display("PASS string synthesis boundary simulation");
  end
endmodule
