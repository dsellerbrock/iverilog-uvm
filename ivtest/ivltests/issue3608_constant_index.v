interface issue3608_bus;
  int value;
endinterface
module issue3608_constant_index;
  issue3608_bus buses[0:1]();
  virtual issue3608_bus selected;
  localparam int INDEX = 1;
  initial begin
    buses[1].value = 42;
    selected = buses[INDEX];
    if (selected.value != 42 || selected != buses[1]) $fatal(1, "wrong interface");
    $display("PASSED");
  end
endmodule
