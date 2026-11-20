module issue3868;
  typedef bit signed [7:0] byte_equiv;

  class packet;
    byte_equiv data[];
    byte bounded[$:1];
  endclass

  byte dyn[];
  byte q[$];
  byte initialized[] = "F!";
  byte bounded[$:2];
  packet p;

  initial begin
    // Repeat the original assignments with both empty and longer destinations.
    for (int pass = 0; pass < 2; pass++) begin
      if (pass != 0) begin
        dyn = "longer";
        q = "test";
        if (dyn.size() != 6 || q.size() != 4)
          $fatal(1, "could not populate the longer destinations");
      end
      dyn = "abc";
      q = "de";
      if (dyn.size() != 3 || q.size() != 2)
        $fatal(1, "literal lengths: dyn=%0d q=%0d", dyn.size(), q.size());
      if (dyn[0] !== 8'h61 || dyn[1] !== 8'h62 || dyn[2] !== 8'h63 ||
          q[0] !== 8'h64 || q[1] !== 8'h65)
        $fatal(1, "literal byte order");
    end

    if (initialized.size() != 2 || initialized[0] !== 8'h46 ||
        initialized[1] !== 8'h21)
      $fatal(1, "dynamic-array declaration initializer");

    p = new;
    p.data = "A\000\377Z";
    if (p.data.size() != 4 || p.data[0] !== 8'h41 || p.data[1] !== 8'h00 ||
        p.data[2] !== 8'hff || p.data[3] !== 8'h5a)
      $fatal(1, "class array literal with embedded NUL and high byte");

    dyn = "";
    q = "";
    if (dyn.size() != 1 || dyn[0] !== 8'h00 ||
        q.size() != 1 || q[0] !== 8'h00)
      $fatal(1, "the empty literal represents one NUL byte");

    bounded = "5689";
    if (bounded.size() != 3 || bounded[0] !== 8'h35 || bounded[1] !== 8'h36 ||
        bounded[2] !== 8'h38)
      $fatal(1, "bounded signal queue must retain the prefix");

    p.bounded = "wxyz!";
    if (p.bounded.size() != 2 || p.bounded[0] !== 8'h77 ||
        p.bounded[1] !== 8'h78)
      $fatal(1, "bounded class queue must retain the prefix");

    $display("PASSED");
  end
endmodule
