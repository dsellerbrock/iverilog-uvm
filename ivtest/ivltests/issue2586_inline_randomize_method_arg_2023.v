module top;
  class P;
    rand int n;
    virtual function int scaled(int k); return k * 2; endfunction
  endclass
  class H extends P;
    virtual function int scaled(int k); return k * 3; endfunction
  endclass

  initial begin
    H h;
    P p;
    h = new;
    p = h;
    if (!p.randomize() with { n == scaled(5); })
      $fatal(1, "randomize failed");
    if (p.n != 15)
      $fatal(1, "wrong virtual result: n=%0d", p.n);
    $display("PASS inline method argument virtual dispatch n=%0d", p.n);
  end
endmodule
