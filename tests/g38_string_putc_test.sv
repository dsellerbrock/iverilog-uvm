// G38: string.putc(idx, ch) modifies string in-place
module top;
  string s;
  initial begin
    s = "Hello";
    s.putc(0, "J");
    if (s == "Jello") begin
      s.putc(4, "y");
      if (s == "Jelly")
        $display("G38_PASS: string.putc works");
      else
        $display("FAIL: putc(4) expected 'Jelly' got '%s'", s);
    end else begin
      $display("FAIL: putc(0) expected 'Jello' got '%s'", s);
    end
    // putc with ch=0 should be no-op per SV spec
    s = "abc";
    s.putc(1, 0);
    if (s == "abc")
      $display("G38_PASS: putc(idx, 0) is no-op");
    else
      $display("FAIL: putc(idx, 0) should be no-op, got '%s'", s);
    $finish;
  end
endmodule
