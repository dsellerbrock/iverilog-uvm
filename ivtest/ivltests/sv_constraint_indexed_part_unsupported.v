class C;
  rand bit [7:0] data;
  rand logic [7:0] four_state;
  rand bit [1:0][7:0] multi;
  rand int index;
  task probe();
    if (!randomize(data) with { data[7+:2] == 2'b0; })
      $fatal(1, "partly out of range");
    if (!randomize(data) with { data[3'bx+:2] == 2'b0; })
      $fatal(1, "unknown base");
    if (!randomize(data) with { data[index+:2] == 2'b0; })
      $fatal(1, "symbolic base");
    if (!randomize(four_state) with { four_state[2+:3] == 3'b001; })
      $fatal(1, "four-state vector");
    if (!randomize(data) with { data[2+:0] == 1'b0; })
      $fatal(1, "zero width");
    if (!randomize(multi) with { multi[0][2+:3] == 3'b001; })
      $fatal(1, "multiple packed dimensions");
  endtask
endclass
module top;
  C c;
  initial begin
    c = new;
    c.probe();
  end
endmodule
