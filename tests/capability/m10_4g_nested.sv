// The export's frame must not be disturbed by nested automatic calls
// inside the exported body, and must survive across a delay.
module top;
  import "DPI-C" context task c_go(input int d, input int id);
  export "DPI-C" task sv_outer;
  int seen[3]; int deep[3];
  function automatic int helper(int v); return v * 10; endfunction
  task automatic inner(input int v, input int id); #(1) deep[id] = helper(v); endtask
  task automatic sv_outer(input int d, input int id);
    seen[id] = d;
    inner(d, id);          // nested automatic call inside the export
    #(d);
    if (seen[id] != d) $display("FAIL frame clobbered id=%0d seen=%0d", id, seen[id]);
  endtask
  initial begin
    int ok = 1;
    for (int i=0;i<3;i++) begin seen[i]=-1; deep[i]=-1; end
    fork c_go(2,0); c_go(4,1); c_go(6,2); join
    if (seen[0]!=2||seen[1]!=4||seen[2]!=6) begin $display("FAIL seen=%0d,%0d,%0d",seen[0],seen[1],seen[2]); ok=0; end
    if (deep[0]!=20||deep[1]!=40||deep[2]!=60) begin $display("FAIL deep=%0d,%0d,%0d",deep[0],deep[1],deep[2]); ok=0; end
    if ($time != 7) begin $display("FAIL t=%0t expect 7", $time); ok=0; end
    if (ok) $display("PASS m10_4g_nested");
    $finish(0);
  end
endmodule
