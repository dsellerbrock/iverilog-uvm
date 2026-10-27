module addfixed_int #(parameter type T=int)(input T a,b); endmodule
module add_float #(parameter type T=real)(input T a,b); endmodule
module p06_23d;
  bit [12:0] A_bus, B_bus;
  parameter type bus_t=type(A_bus);
  generate
    case (type(bus_t))
      type(bit[12:0]): addfixed_int #(bus_t) f(A_bus,B_bus);
      type(real): add_float #(type(A_bus)) r(A_bus,B_bus);
    endcase
  endgenerate
endmodule
