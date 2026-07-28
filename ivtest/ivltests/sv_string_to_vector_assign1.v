// A string VARIABLE assigned to an integral variable must pack its
// ASCII bytes right-justified with zero-pad above, the same as a
// string literal does (IEEE 1800-2017 6.16). Both halves of this were
// broken (br_ml20180227): the front end substituted a compile-time
// constant ZERO for the whole assignment (a compile-progress fallback
// for lost container typing over-firing on a well-typed string), and
// once that was fixed the %cast/vec4/str opcode left-justified the
// value whenever the target was wider than the string.
module test;

  string str;
  reg [127:0] b128;  // wider: zero-pad on the left
  reg [39:0]  b40;   // exact width
  reg [23:0]  b24;   // narrower: keep the rightmost characters
  bit [39:0]  bb40;  // 2-state target
  int fails = 0;

  initial begin
    str = "hello";
    b128 = str;
    b40  = str;
    b24  = str;
    bb40 = str;
    if (b128 !== 128'h68656c6c6f) begin fails++; $display("FAILED b128=%h", b128); end
    if (b40  !== 40'h68656c6c6f)  begin fails++; $display("FAILED b40=%h",  b40);  end
    if (b24  !== 24'h6c6c6f)      begin fails++; $display("FAILED b24=%h",  b24);  end
    if (bb40 !== 40'h68656c6c6f)  begin fails++; $display("FAILED bb40=%h", bb40); end

    str = "";
    b40 = str;
    if (b40 !== 40'h0) begin fails++; $display("FAILED empty=%h", b40); end

    if (fails == 0) $display("PASSED");
  end

endmodule
