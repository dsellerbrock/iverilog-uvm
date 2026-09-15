module sv_const_array_string_character_incdec_bounds;
  function automatic int folded;
    string words[2:3];
    logic [127:0] wide = 128'h1_0000_0000_0000_0000;
    logic [63:0] unknown = 'x;
    int signed_old;
    int signed_new;
    longint wide_signed_old;
    logic [63:0] wide_unsigned_new;
    byte invalid_post;
    byte invalid_pre;
    words[2] = "\310\377";
    words[3] = "keep";
    signed_old = words[2][0]++;
    signed_new = ++words[2][0];
    if (signed_old != -56 || signed_new != -54
        || words[2][0] != 8'hca || words[2] != "\312\377")
      return 0;
    if (++words[2][1] != 0 || words[2][1] != 8'hff
        || words[2] != "\312\377") return 0;
    words[3] = "\310";
    wide_signed_old = words[3][0]++;
    wide_unsigned_new = ++words[3][0];
    if (wide_signed_old != -56
        || wide_unsigned_new != 64'hffff_ffff_ffff_ffca
        || words[3] != "\312") return 0;
    words[3] = "keep";
    invalid_post = words[wide][0]++;
    invalid_pre = ++words[unknown][0];
    if (invalid_post != 0 || invalid_pre != 1 || words[3] != "keep") return 0;
    invalid_post = words[2][wide]++;
    invalid_pre = ++words[2][unknown];
    if (invalid_post != -54 || invalid_pre != -52 || words[2][0] != 8'hcc
        || words[2] != "\314\377")
      return 0;
    words[3] = "";
    if (++words[3][-1] != 1 || words[3] != "") return 0;
    return 1;
  endfunction
  localparam int OK = folded();
  initial begin
    if (!OK || !folded())
      $fatal(1, "constant/runtime array character bounds failed");
    $display("PASSED");
  end
endmodule
