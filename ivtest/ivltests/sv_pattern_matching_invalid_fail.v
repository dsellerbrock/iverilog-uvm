module top;
  typedef struct packed { logic [3:0] x, y; } plain_t;
  typedef union tagged packed {
    struct packed { logic [3:0] x, y; } a;
    struct packed { logic [3:0] x, y; } b;
  } value_t;

  plain_t plain;
  value_t value;
  logic [7:0] scalar;

  initial begin
    if (plain matches tagged a .*) ;
    if (value matches tagged missing) ;
    if (value matches tagged a '{.*, .*, .*}) ;
    if (scalar matches '{.*}) ;
  end
endmodule
