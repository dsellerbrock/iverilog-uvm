module sv_format_string_byte_array;
  byte bytes [1:0];
  initial begin
    bytes[1] = "x";
    bytes[0] = "y";
    $display("[%s]", bytes);
  end
endmodule
