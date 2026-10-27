virtual class C#(parameter DECODE_W, parameter ENCODE_W = $clog2(DECODE_W));
  static function logic [ENCODE_W-1:0] ENCODER_f(input logic [DECODE_W-1:0] DecodeIn);
    ENCODER_f = '0;
    for (int i = 0; i < DECODE_W; i++) begin
      if (DecodeIn[i]) begin ENCODER_f = i[ENCODE_W-1:0]; break; end
    end
  endfunction

  static function logic [DECODE_W-1:0] DECODER_f(input logic [ENCODE_W-1:0] EncodeIn);
    DECODER_f = '0; DECODER_f[EncodeIn] = 1'b1;
  endfunction
endclass

module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask

  logic [7:0] encoder_in;
  logic [2:0] encoder_out;
  logic [1:0] decoder_in;
  logic [3:0] decoder_out;
  assign encoder_in = 8'b0100_0000;
  assign decoder_in = 2'b11;
  assign encoder_out = C#(8)::ENCODER_f(encoder_in);
  assign decoder_out = C#(4)::DECODER_f(decoder_in);
  int fr;

  function int outer(int x);
    return x * 2;
  endfunction

  initial begin
    fr = later_f(); chk("13.7.forward_ref_function", fr == 11);
    later_t(); chk("13.7.forward_ref_task", fr == 12);
    begin : nest chk("13.7.enclosing_scope_function_from_named_block", outer(2) == 4); end
    #1;
    chk("13.8.spec_example_encoder_out", encoder_out == 3'd6);
    chk("13.8.spec_example_decoder_out", decoder_out == 4'b1000);
    chk("13.8.encoder_C8", C#(8)::ENCODER_f(8'b0010_0000) == 3'd5);
    chk("13.8.decoder_C8", C#(8)::DECODER_f(3'd5) == 8'b0010_0000);
    chk("13.8.encoder_C16_default_encode_w", C#(16)::ENCODER_f(16'h0100) == 4'd8);
    chk("13.8.encoder_C4", C#(4)::ENCODER_f(4'b0100) == 2'd2);
    chk("13.8.explicit_encode_w_override", C#(8, 5)::ENCODER_f(8'b0010_0000) == 5'd5);
    $display("DONE fails=%0d", fails);
  end

  function int later_f(); return 11; endfunction
  task later_t(); fr = 12; endtask
endmodule
