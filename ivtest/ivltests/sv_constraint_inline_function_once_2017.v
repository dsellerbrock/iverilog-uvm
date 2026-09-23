class packet;
  rand int n;
`ifdef CLASS_CONTROL
  constraint c { n == value(); }
`endif
  function int value(); return 7; endfunction
endclass
module receiver_once;
  int calls; packet req = new(); packet targets[1];
  function int index_once(); calls++; return 0; endfunction
  initial begin
    targets[0] = req;
`ifdef CLASS_CONTROL
    if (!targets[index_once()].randomize()) $fatal(1, "receiver solve failed");
`else
    if (!targets[index_once()].randomize() with { n == value(); }) $fatal(1, "receiver solve failed");
`endif
    if (req.n != 7 || calls != 1) $fatal(1, "receiver result/call count wrong: n=%0d calls=%0d", req.n, calls);
    $display("PASS receiver_once n=%0d calls=%0d", req.n, calls);
  end
endmodule
