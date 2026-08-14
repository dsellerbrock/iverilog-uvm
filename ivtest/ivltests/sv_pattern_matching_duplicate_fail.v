module top;
  typedef union tagged packed {
    struct packed { logic [3:0] x, y; } a;
    struct packed { logic [3:0] x, y; } b;
  } value_t;

  value_t value;

  initial begin
    if (value matches tagged a '{.same, .same}) ;
  end
endmodule
