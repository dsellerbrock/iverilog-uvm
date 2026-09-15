module sv_const_string_array_method;
  function automatic int folded;
    string words[6];
    int index = 0;
    words[0] = "old";
    words[index++].itoa(-31);
    if (index != 1 || words[0] != "-31") return 0;
    words[1].hextoa(255);
    words[2].octtoa(8);
    words[3].bintoa(5);
    words[4].realtoa(1.5);
    words[5] = "abc";
    words[5].putc(1, "Z");
    return words[1] == "ff" && words[2] == "10"
        && words[3] == "101" && words[4] == "1.5"
        && words[5] == "aZc";
  endfunction

  localparam int OK = folded();
  initial begin
    if (!OK) $fatal(1, "constant fixed string-array methods failed");
    $display("PASSED");
  end
endmodule
