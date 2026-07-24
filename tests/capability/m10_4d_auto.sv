module top;
  import "DPI-C" context task c_slow(input int d, input int id);
  export "DPI-C" task sv_wait;
  task automatic sv_wait(input int d, input int id);
    $display("  [%0t] auto sv_wait enter id=%0d d=%0d", $time, id, d);
    #(d);
    $display("  [%0t] auto sv_wait exit  id=%0d d=%0d", $time, id, d);
  endtask
  initial begin
    fork c_slow(5,0); c_slow(3,1); join
    $display("[%0t] join done", $time);
    #5 $finish(0);
  end
endmodule
