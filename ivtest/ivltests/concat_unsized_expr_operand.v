// Check that concatenation operands that are expressions containing
// unsized literals are accepted and take their IEEE 1800-2017
// self-determined width (32 bits for integer arithmetic), while the
// values follow standard (truncating) 32-bit evaluation.
//
// Reduced from OpenTitan aes_wrap.sv:
//   h2d.a_address = {{{32-BlockAw}{1'b0}}, AES_STATUS_OFFSET};
module main;
  parameter int P = 12;
  parameter Q = 12; // untyped parameter, unsized value
  logic [63:0] a, b, c, d, e;
  initial begin
    a = {1'b0, 32-P};           // 33 bits: {0, 32'd20}
    b = {1'b1, 2**34};          // 2**34 overflows 32-bit => 0
    c = {4'hF, -1};             // unary minus expression => 32'hffff_ffff
    d = {{{32-P}{1'b1}}, 4'h5}; // replication count is a concat expression
    e = {1'b0, Q};              // untyped parameter operand
    if (a !== 64'h14) begin $display("FAILED a=%h", a); $finish; end
    if (b !== 64'h1_0000_0000) begin $display("FAILED b=%h", b); $finish; end
    if (c !== 64'hf_ffff_ffff) begin $display("FAILED c=%h", c); $finish; end
    if (d !== 64'hff_fff5) begin $display("FAILED d=%h", d); $finish; end
    if (e !== 64'hc) begin $display("FAILED e=%h", e); $finish; end
    $display("PASSED");
  end
endmodule
