class scalar_z_constraint;
  rand logic [3:0] en;
  constraint illegal_value { en == 4'hz; }
endclass

module main;
  scalar_z_constraint obj;
  initial begin
    obj = new;
    if (obj.randomize()) $fatal(1, "illegal Z constraint accepted");
  end
endmodule
