module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  real AOR[];
  int woke;
  initial begin
    @(AOR.size());
    woke = 1;
  end
  initial begin
    #1 AOR = new[3];
    #1 chk("9.4.2.dynamic_array_size_event", AOR.size() == 3 && woke == 1);
    $display("DONE fails=%0d", fails); $finish;
  end
endmodule
