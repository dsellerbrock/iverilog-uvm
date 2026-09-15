module sv_const_string_array_method_bounds;
  function automatic int folded;
    string words[3:2];
    logic [63:0] unknown = 'x;
    logic signed [1:0] negative = -1;
    int calls = 1;
    words[3] = "left";
    words[2] = "right";
    words[64'h1_0000_0000].itoa(calls++);
    words[128'h1_0000_0000_0000_0000].bintoa(calls++);
    words[negative].hextoa(calls++);
    words[unknown].realtoa(calls++);
    words[3].putc(calls++, calls++);
    if (calls != 7 || words[3] != "left" || words[2] != "right") return 0;
    words[2].putc(1, 0);
    words[2].putc(-1, "Z");
    words[2].putc(99, "Z");
    return words[2] == "right";
  endfunction

  localparam int OK = folded();
  initial begin
    if (!OK) $fatal(1, "constant bounds/once behavior failed");
    $display("PASSED");
  end
endmodule
