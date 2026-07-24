module top;
  import "DPI-C" context task c_a(input int d);
  import "DPI-C" context task c_b(input int d);
  export "DPI-C" task sv_a;
  export "DPI-C" task sv_b;
  task sv_a(input int d); $display("  [%0t] sv_a d=%0d", $time, d); #(d); $display("  [%0t] sv_a done d=%0d", $time, d); endtask
  task sv_b(input int d); $display("  [%0t] sv_b d=%0d", $time, d); #(d); $display("  [%0t] sv_b done d=%0d", $time, d); endtask
  initial begin
    fork c_a(5); c_b(3); join
    $display("[%0t] join done (expect 5)", $time);
    #5 $finish(0);
  end
endmodule
