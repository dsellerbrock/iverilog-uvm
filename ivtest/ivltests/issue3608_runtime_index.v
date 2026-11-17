interface issue3608_bus;
endinterface
module issue3608_runtime_index;
  issue3608_bus buses[0:1]();
  virtual issue3608_bus selected;
  int index;
  initial begin
    index = 1;
    selected = buses[index];
    selected = buses[index * 0];
    selected = buses[0 ? index : 1];
    if (selected == buses[index]) $display("unexpected acceptance");
  end
endmodule
