virtual class C#(parameter DECODE_W, parameter ENCODE_W = $clog2(DECODE_W));
  static function logic [ENCODE_W-1:0] ENCODER_f(input logic [DECODE_W-1:0] DecodeIn);
    ENCODER_f = '0;
    for (int i = 0; i < DECODE_W; i++) begin
      if (DecodeIn[i]) ENCODER_f = i[ENCODE_W-1:0];
    end
  endfunction

  static function logic [DECODE_W-1:0] DECODER_f(input logic [ENCODE_W-1:0] EncodeIn);
    DECODER_f = '0;
    DECODER_f[EncodeIn] = 1'b1;
  endfunction
endclass

module p13_07_08_parameterized;
  int slot;

  initial begin : nested_caller
    if (add_five(4) != 9) $fatal(1, "13.7 forward function lookup");
    set_later(13);
    if (get_later() != 13) $fatal(1, "13.7 forward task lookup");

    if (C#(8)::ENCODER_f(8'b0010_0000) !== 3'd5)
      $fatal(1, "13.8 C#(8) encoder");
    if (C#(8)::DECODER_f(3'd5) !== 8'b0010_0000)
      $fatal(1, "13.8 C#(8) decoder");
    if (C#(16)::ENCODER_f(16'b0000_0010_0000_0000) !== 4'd9)
      $fatal(1, "13.8 C#(16) encoder");
    if (C#(16)::DECODER_f(4'd9) !== 16'b0000_0010_0000_0000)
      $fatal(1, "13.8 C#(16) decoder");

    $display("PASS 13.7 forward lookup and 13.8 parameterized subroutines");
  end

  task set_later(input int value);
    slot = value;
  endtask

  function int get_later();
    return slot;
  endfunction

  function automatic int add_five(input int value);
    return value + 5;
  endfunction
endmodule
