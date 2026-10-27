module top;
  supply1 vdd;
  tri supply_out;
  rnmos supply_switch(supply_out, vdd, 1'b1);

  tri pull_source;
  pullup (pull_source);
  tri pull_out;
  rnmos pull_switch(pull_out, pull_source, 1'b1);

  initial begin
    #1;
    $display("%v %v", supply_out, pull_out);
    $finish;
  end
endmodule
