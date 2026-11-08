// IEEE 1800-2017/2023 24.6: an anonymous program declares programwide
// items in the enclosing package or compilation unit, without a new
// scope; program blocks reference them like any package/unit item.
package pk;
  program;
    function automatic int twice(int v); return 2 * v; endfunction
    task automatic hello(output int r);
      r = twice(21);          // anonymous item calling another
    endtask
    class counter;
      int n;
      function void bump(); n += 1; endfunction
    endclass
  endprogram
  int plain = 5;              // an ordinary package item beside it
endpackage

program;
  function automatic int unit_add(int a, int b); return a + b; endfunction
endprogram

program p_wild;
  import pk::*;
  initial begin : run
    int r;
    automatic counter c = new;
    hello(r);
    c.bump(); c.bump();
    if (r !== 42 || c.n !== 2 || plain !== 5) $display("FAILED wild r=%0d n=%0d", r, c.n);
    else $display("wild ok");
  end
endprogram

program p_qual;
  import pk::twice;
  initial begin
    #1;
    if (twice(4) !== 8 || pk::twice(5) !== 10 || unit_add(3, 4) !== 7)
      $display("FAILED qual");
    else $display("qual ok");
    #1 $display("PASSED");
  end
endprogram

// A module that wildcard-imports pk may declare its own items with the
// same names; nothing here references the anonymous-program items.
module m_shadow;
  import pk::*;
  int hello, twice;
  initial begin hello = 1; twice = 2; end
endmodule
