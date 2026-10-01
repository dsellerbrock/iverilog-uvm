class item;
  int value;
endclass
module top;
  task static sample();
    item trans = new();
    trans.value++;
    $display("value=%0d", trans.value);
  endtask
  initial begin sample(); sample(); end
endmodule
