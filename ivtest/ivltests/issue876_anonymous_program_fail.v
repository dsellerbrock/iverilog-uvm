// IEEE 1800-2017/2023 24.6: "The set of program definitions and instances
// define a space of program-wide data, tasks, and functions that is
// accessible only to programs." Every reference below is from a module.
package pk;
  program;
    function automatic int twice(int v); return 2 * v; endfunction
  endprogram
  function automatic int plain(int v); return v; endfunction
endpackage

program;
  function automatic int unit_add(int a, int b); return a + b; endfunction
endprogram

module m_wild;
  import pk::*;
  initial $display(twice(1), plain(1));   // plain() is fine
endmodule

module m_qual;
  import pk::twice;
  initial $display(pk::twice(2));
endmodule

module m_unit;
  initial $display(unit_add(1, 2));
endmodule

module m_call;
  initial begin
    int r;
    r = pk::twice(3);
    pk::twice(4);
  end
endmodule

