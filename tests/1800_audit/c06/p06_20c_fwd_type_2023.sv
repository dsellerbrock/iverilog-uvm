module sub #(parameter type enum E = enum {A0, A1},
             parameter type struct S = struct packed {bit [3:0] f;});
  E e;
  S s;
  initial begin
    e = E'(1);
    s.f = 4'h5;
    $display("FWD e=%0d s=%h bits=%0d", e, s.f, $bits(S));
  end
endmodule

typedef enum {R, G, B} col_t;
module p06_20c;
  sub u1();
  sub #(.E(col_t)) u2();
endmodule
