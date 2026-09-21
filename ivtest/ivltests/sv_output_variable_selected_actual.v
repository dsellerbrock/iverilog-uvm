module selected_source(input logic flip, output logic [1:0] out);
  always_comb out = flip ? 2'b01 : 2'b10;
endmodule

module test;
  logic flip;
  logic [3:0] actual;
  selected_source source(flip, actual[2:1]);
  initial begin
    flip = 0;
    #1;
    if (actual[2:1] !== 2'b10) $fatal(1, "selected initial: %b", actual);
    flip = 1;
    #1;
    if (actual[2:1] !== 2'b01) $fatal(1, "selected update: %b", actual);
    $display("PASS selected variable actual");
  end
endmodule
