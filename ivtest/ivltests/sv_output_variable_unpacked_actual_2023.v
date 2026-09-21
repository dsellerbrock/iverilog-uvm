module unpacked_source(input logic flip, output logic [7:0] out [2]);
  always_comb begin
    out[0] = flip ? 8'h12 : 8'ha5;
    out[1] = flip ? 8'h34 : 8'h5a;
  end
endmodule

module test;
  logic flip;
  logic [7:0] actual [2];
  unpacked_source source(flip, actual);
  initial begin
    flip = 0;
    #1;
    if (actual[0] !== 8'ha5 || actual[1] !== 8'h5a)
      $fatal(1, "unpacked initial: %h %h", actual[0], actual[1]);
    flip = 1;
    #1;
    if (actual[0] !== 8'h12 || actual[1] !== 8'h34)
      $fatal(1, "unpacked update: %h %h", actual[0], actual[1]);
    $display("PASS unpacked variable actual");
  end
endmodule
