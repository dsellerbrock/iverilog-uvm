module top;
  import "DPI-C" context function int  c_call1(input int v);
  import "DPI-C" context task          c_slow1(input int d);
  export "DPI-C" function sv_fauto;
  export "DPI-C" task     sv_tauto;
  int seen_d = -1;
  function automatic int sv_fauto(int x);
    $display("  sv_fauto x=%0d", x); return x + 1;
  endfunction
  task automatic sv_tauto(input int d);
    $display("  [%0t] sv_tauto d=%0d", $time, d); #(d); seen_d = d;
  endtask
  initial begin
    int r, ok = 1;
    r = c_call1(4);                     // single automatic FUNCTION export
    if (r != 5) begin $display("FAIL auto fn r=%0d (expect 5)", r); ok = 0; end
    c_slow1(6);                         // single automatic TASK export
    if ($time != 6) begin $display("FAIL auto task time=%0t (expect 6)", $time); ok = 0; end
    if (seen_d != 6) begin $display("FAIL auto task seen_d=%0d", seen_d); ok = 0; end
    if (ok) $display("PASS m10_4f");
    $finish(0);
  end
endmodule
