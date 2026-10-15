// IEEE 1800-2017/2023 §§6.6.8, 23.3.3.8; issue #436.
module issue436_signed_driver(output wire signed [3:0] value);
  assign value = -4'sd3;
endmodule

module issue436_scalar_driver(output wire value);
  assign value = 1'b0;
endmodule

module issue436_signed_sink(input wire [4:0] value);
  initial begin
    #1;
    if (value !== 5'b11010)
      $fatal(1, "signed interconnect concat mismatch: %b", value);
    $display("PASS: signed-vector and scalar interconnect concatenation");
  end
endmodule

module issue436_signed_concat;
  interconnect [3:0] vector_link;
  interconnect scalar_link;

  issue436_signed_driver vector_driver(vector_link);
  issue436_scalar_driver scalar_driver(scalar_link);
  issue436_signed_sink sink({vector_link, scalar_link});

  initial begin
    #2;
    $display("PASSED");
  end
endmodule
