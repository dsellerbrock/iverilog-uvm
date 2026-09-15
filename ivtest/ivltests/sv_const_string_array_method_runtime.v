module sv_const_string_array_method_runtime;
  function automatic string recurse(input int depth);
    string words[-1:0];
    words[-1] = "abc";
    words[0].itoa(depth);
    words[-1].putc(1, "Z");
    if (depth == 0) return {words[-1], words[0]};
    return {words[-1], words[0], recurse(depth-1)};
  endfunction

  initial begin
    string words[6];
    string snapshot[2];
    string signed_words[0:-1];
    integer integers[2];
    longint unsigned wide;
    logic [127:0] wider;
    logic [63:0] unknown;
    logic signed [1:0] negative;
    int index;
    wide = 64'h1_0000_0000;
    wider = 128'h1_0000_0000_0000_0000;
    unknown = 'x;
    negative = -1;
    index = 0;

    integers[0] = 3;
    integers[1] = 4;
    if ($sscanf("17", "%d", integers[1]) != 1)
      $fatal(1, "fixed-array VPI control conversion failed");
    void'($sscanf("99", "%d", integers[wide]));
    if (integers[0] != 3 || integers[1] != 17)
      $fatal(1, "fixed-array VPI bounds control failed");

    signed_words[-1] = "old";
    signed_words[negative].itoa(-9);
    signed_words[unknown].putc(index++, index++);
    if (signed_words[-1] != "-9" || index != 2)
      $fatal(1, "signed/invalid runtime receiver behavior failed");
    index = 0;

    snapshot[0] = "old";
    snapshot[1] = "keep";
    snapshot[index].itoa(index++);
    if (index != 1 || snapshot[0] != "0" || snapshot[1] != "keep")
      $fatal(1, "receiver was not captured before the explicit argument");
    index = 0;
    words[index++].itoa(-31);
    words[1].hextoa(255);
    words[2].octtoa(8);
    words[3].bintoa(5);
    words[4].realtoa(1.5);
    words[5] = "abc";
    words[5].putc(1, "Z");
    words[wide].itoa(7);
    words[wider].bintoa(7);
    if (index != 1 || words[0] != "-31" || words[1] != "ff"
        || words[2] != "10" || words[3] != "101"
        || words[4] != "1.5" || words[5] != "aZc")
      $fatal(1, "runtime fixed string-array methods failed");
    if (recurse(2) != "aZc2aZc1aZc0")
      $fatal(1, "automatic recursive frames failed: %s", recurse(2));
    $display("PASSED");
  end
endmodule
