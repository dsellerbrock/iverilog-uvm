module test;
  typedef struct { int x; string s; } s_t;
  s_t a, b, c;

  initial begin
    a = '{1, "s"};
    b = '{1, "s"};
    c = '{1, "t"};
    if (!(a == b) || !(a === b) || !(a !== c) || (a === c))
      $fatal(1, "unpacked struct string equality failed");
    $display("PASSED");
  end
endmodule
