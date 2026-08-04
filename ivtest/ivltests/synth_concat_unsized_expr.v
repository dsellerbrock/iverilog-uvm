`begin_keywords "1800-2012"

// OpenTitan aes_wrap.sv address composition shape: a zero-extension
// built from a replication whose count is a braced constant expression
// containing unsized literals:
//   h2d.a_address = {{{32-BlockAw}{1'b0}}, AES_STATUS_OFFSET};
// This must synthesize and produce the standard 32-bit self-determined
// value.
module main;
  parameter int BlockAw = 12;
  localparam logic [BlockAw-1:0] OFF = 12'h1c;

  logic       sel;
  logic [31:0] addr;

  always_comb begin
    if (sel)
      addr = {{{32-BlockAw}{1'b0}}, OFF};
    else
      addr = {{{32-BlockAw}{1'b1}}, OFF};
  end

  initial begin
    sel = 1'b1;
    #1;
    if (addr !== 32'h0000_001c) begin
      $display("FAILED addr=%h", addr);
      $finish;
    end
    sel = 1'b0;
    #1;
    if (addr !== 32'hffff_f01c) begin
      $display("FAILED addr=%h", addr);
      $finish;
    end
    $display("PASSED");
  end
endmodule

`end_keywords
