// IEEE 1800-2017/2023 6.22.1(e),(f): packed ranges and dimensions match.
module sv_type_operator_packed_shape;
  typedef bit signed [7:0] BYTE;
  typedef bit signed [0:7] ETYB;
  typedef logic [1:0][3:0] NIBBLES;
  typedef logic [7:0] MY_BYTE;
  typedef bit signed [7:0] BYTE_ALIAS;

  initial begin
    if (type(BYTE) != type(byte)) $fatal(1, "BYTE must match byte");
    if (type(BYTE) != type(BYTE_ALIAS)) $fatal(1, "typedef aliases must match");
    if (type(ETYB) == type(byte)) $fatal(1, "opposite range direction matched");
    if (type(NIBBLES) == type(MY_BYTE)) $fatal(1, "packed dimensions were flattened");
    $display("PASSED");
  end
endmodule
