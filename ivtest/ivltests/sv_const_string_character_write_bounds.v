module sv_const_string_character_write_bounds;
  function automatic string mutate(input string text);
    logic [127:0] wide, mixed;
    logic signed [127:0] negative;
    wide = 128'bx;
    text[wide] = "Z";
    mixed = {{126{1'b0}},2'b1x};
    text[mixed] = "Y";
    wide = 128'h1_0000000000000000000000000;
    text[wide] = "X";
    negative = -1;
    text[negative] = "W";
    text[1] = 0;
    text[8] = "Q";
    return text;
  endfunction
  function automatic string uninitialized_local();
    string text;
    text[0] = "Z";
    return text;
  endfunction
  localparam string VALUE = mutate("ABC");
  localparam string EMPTY = mutate("");
  localparam string UNINITIALIZED = uninitialized_local();
  initial begin
    if (VALUE != "XBY" || EMPTY != "" || UNINITIALIZED != "")
      $fatal(1, "bounds/zero write failed: %s/%s/%s",
             VALUE, EMPTY, UNINITIALIZED);
    $display("PASSED");
  end
endmodule
