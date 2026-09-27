// Synthesizability checks of an always_comb follow called subroutines once.
// A recursive void function recursed without bound and overflowed the
// compiler's stack (OpenTitan entropy_src reached UVM's recursive report
// helpers this way).
module test;
  int acc;
  function automatic void walk(int n);
    if (n <= 0) return;
    acc += n;
    walk(n - 1);
  endfunction
  int n = 3, y;
  always_comb begin
    acc = 0;
    walk(n);
    y = acc;
  end
  initial begin
    #1 n = 5; #1;
    if (y == 15) $display("PASSED"); else $display("FAILED %0d", y);
  end
endmodule
