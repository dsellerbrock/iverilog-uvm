module issue2495_string_index_x;
  string s, a[1];
  logic [7:0] m;
  byte c1, c2, c3;

  initial begin
    m = 8'b0000_001x;
    s = "abcd";
    a[0] = "abcd";
    c1 = s[m];
    c2 = a[0][m];
    c3 = s.getc(m);
    if (c1 != "c" || c2 != "c" || c3 != "c")
      $fatal(1, "partly-X string index: %c %c %c", c1, c2, c3);
    $display("PASS partly-X string indices match getc");
  end
endmodule
