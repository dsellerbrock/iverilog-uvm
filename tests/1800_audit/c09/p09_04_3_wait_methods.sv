module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  real AOR[]; int hitA; time tA;
  initial begin wait (AOR.size() > 0); hitA = 1; tA = $time; end
  initial begin
    #5 AOR = new[2];
    #1;
    chk("9.4.3.wait_dynamic_array_size", hitA == 1 && tA == 5);
    $display("DONE fails=%0d", fails); $finish;
  end
endmodule
