module p10_09_struct_default_nested_array;
  typedef struct { int x; int y[2]; } T;
  T t;
  initial begin
    t = '{default:5};
    $display("N1 %0d %0d %0d", t.x, t.y[0], t.y[1]);
    t = '{x:1, default:6};
    $display("N2 %0d %0d %0d", t.x, t.y[0], t.y[1]);
  end
endmodule
