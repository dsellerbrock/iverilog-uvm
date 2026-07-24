module top;
  import "DPI-C" context task c_slow(input int d, input int id);
  export "DPI-C" task sv_wait;
  task sv_wait(input int d, input int id);
    $display("  [%0t] sv_wait enter id=%0d d=%0d", $time, id, d);
    #(d);
    $display("  [%0t] sv_wait exit  id=%0d", $time, id);
  endtask
  initial begin
    $display("[%0t] fork start", $time);
    fork
      begin $display("[%0t] br0 call", $time); c_slow(5,0); $display("[%0t] br0 ret", $time); end
      begin $display("[%0t] br1 call", $time); c_slow(3,1); $display("[%0t] br1 ret", $time); end
    join
    $display("[%0t] join done", $time);
    #20 $finish(0);
  end
endmodule
