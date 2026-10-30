virtual class C #(parameter DECODE_W, parameter ENCODE_W = $clog2(DECODE_W));
  static function logic [ENCODE_W-1:0] ENCODER_f
      (input logic [DECODE_W-1:0] DecodeIn);
    ENCODER_f = '0;
    for (int i = 0; i < DECODE_W; i++) begin
      if (DecodeIn[i]) begin
        ENCODER_f = i[ENCODE_W-1:0];
        break;
      end
    end
  endfunction

  static function logic [DECODE_W-1:0] DECODER_f
      (input logic [ENCODE_W-1:0] EncodeIn);
    DECODER_f = '0;
    DECODER_f[EncodeIn] = 1'b1;
  endfunction
endclass

class K;
  static function automatic int dbl(input int a);
    return 2*a;
  endfunction
endclass

module top;
  logic [7:0] encoder_in;
  logic [2:0] encoder_out;
  logic [1:0] decoder_in;
  logic [3:0] decoder_out;
  int plain_in;
  int plain_out;
  logic [2:0] encoder_proc;
  logic [3:0] decoder_proc;
  int plain_proc;

  assign encoder_out = C#(8)::ENCODER_f(encoder_in);
  assign decoder_out = C#(4)::DECODER_f(decoder_in);
  assign plain_out = K::dbl(plain_in);

  initial begin
    encoder_in = 8'b0100_0000;
    decoder_in = 2'b11;
    plain_in = 3;
    #1;
    encoder_proc = C#(8)::ENCODER_f(encoder_in);
    decoder_proc = C#(4)::DECODER_f(decoder_in);
    plain_proc = K::dbl(plain_in);
    if (encoder_out !== encoder_proc || encoder_out !== 3'd6 ||
        decoder_out !== decoder_proc || decoder_out !== 4'b1000 ||
        plain_out !== plain_proc || plain_out !== 6)
      $fatal(1, "continuous static method result mismatch");
    $display("PASSED");
    $finish;
  end
endmodule
