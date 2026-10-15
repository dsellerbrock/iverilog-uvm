// IEEE 1800-2017/2023 §§6.6.8, 23.3.3.7.1; issue #436.
module issue436_driver4(output wire [3:0] value);
  assign value = 4'b1010;
endmodule

module issue436_driver1 #(parameter bit VALUE = 1'b0)(output wire value);
  assign value = VALUE;
endmodule

module issue436_sink5(input wire [4:0] value);
  initial begin
    #1;
    if (value !== 5'b11010)
      $fatal(1, "selected/generic concat mismatch: %b", value);
    $display("PASS: selected plus generic scalar interconnect operands");
  end
endmodule

module issue436_sink2(input wire [1:0] value);
  initial begin
    #1;
    if (value !== 2'b10)
      $fatal(1, "unpacked-word concat mismatch: %b", value);
    $display("PASS: per-word unpacked interconnect concat");
  end
endmodule

module issue436;
  interconnect [3:0] packed_link;
  interconnect scalar_link;
  interconnect word_link [0:1];

  issue436_driver4 packed_driver(packed_link);
  issue436_driver1 #(.VALUE(1'b1)) scalar_driver(scalar_link);
  issue436_driver1 #(.VALUE(1'b0)) word_driver0(word_link[0]);
  issue436_driver1 #(.VALUE(1'b1)) word_driver1(word_link[1]);

  issue436_sink5 selected_generic_sink(
    {packed_link[3], packed_link[1:0], scalar_link, packed_link[2]});
  issue436_sink2 word_sink({word_link[1], word_link[0]});

  initial begin
    #2;
    $display("PASSED");
  end
endmodule
