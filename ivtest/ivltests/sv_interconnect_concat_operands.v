// Issue #436: selected, generic, unpacked, and signed interconnect operands.
module sv_interconnect_concat_driver4(output wire [3:0] value);
  assign value = 4'b1010;
endmodule

module sv_interconnect_concat_driver1 #(parameter bit VALUE = 1'b0)(
  output wire value
);
  assign value = VALUE;
endmodule

module sv_interconnect_concat_signed_driver(output wire signed [3:0] value);
  assign value = -4'sd3;
endmodule

module sv_interconnect_concat_sink(
  input wire [4:0] selected_generic,
  input wire [1:0] unpacked_words,
  input wire [4:0] signed_vector
);
  initial begin
    #1;
    if (selected_generic !== 5'b11010 || unpacked_words !== 2'b10 ||
        signed_vector !== 5'b11010)
      $fatal(1, "interconnect concat mismatch: %b %b %b",
             selected_generic, unpacked_words, signed_vector);
    $display("PASSED");
  end
endmodule

module sv_interconnect_concat_operands;
  interconnect [3:0] packed_link;
  interconnect scalar_link;
  interconnect word_link [0:1];
  interconnect [3:0] signed_link;
  interconnect signed_scalar_link;

  sv_interconnect_concat_driver4 packed_driver(packed_link);
  sv_interconnect_concat_driver1 #(.VALUE(1'b1)) scalar_driver(scalar_link);
  sv_interconnect_concat_driver1 #(.VALUE(1'b0)) word_driver0(word_link[0]);
  sv_interconnect_concat_driver1 #(.VALUE(1'b1)) word_driver1(word_link[1]);
  sv_interconnect_concat_signed_driver signed_driver(signed_link);
  sv_interconnect_concat_driver1 #(.VALUE(1'b0)) signed_scalar_driver(
    signed_scalar_link);

  sv_interconnect_concat_sink sink(
    {packed_link[3], packed_link[1:0], scalar_link, packed_link[2]},
    {word_link[1], word_link[0]},
    {signed_link, signed_scalar_link}
  );
endmodule
