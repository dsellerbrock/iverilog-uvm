module p10_09_nested_default_controls;
  typedef struct { int x; int y[2]; } T;
  int matrix[2][2];
  T t;
  initial begin
    matrix = '{default:4};
    $display("M %0d %0d %0d %0d", matrix[0][0], matrix[0][1], matrix[1][0], matrix[1][1]);
    t = '{x:0, y:'{5,5}};
    $display("C1 %0d %0d %0d", t.x, t.y[0], t.y[1]);
    t = '{x:1, y:'{default:6}};
    $display("C2 %0d %0d %0d", t.x, t.y[0], t.y[1]);
  end
endmodule
