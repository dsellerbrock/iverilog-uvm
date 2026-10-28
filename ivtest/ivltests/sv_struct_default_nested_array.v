// IEEE 1800-2017/2023 10.9.2: structure defaults descend into arrays.
module test;
  typedef struct { int x; int y[2]; } T;
  typedef struct { T child; } Outer;
  typedef struct { int values[2][3]; } Matrix;
  typedef struct packed { logic [3:0] a; logic [7:0] b; } Packed;
  typedef struct { Packed value; } PackedOuter;
  typedef struct { int values[2]; } Inner;
  typedef struct { Inner value; } SameTypeOuter;

  T t;
  Outer outer;
  Matrix matrix;
  Packed top_packed;
  PackedOuter packed_outer;
  Inner source;
  SameTypeOuter same_type;

  initial begin
    t = '{default:5};
    $display("plain %0d %0d %0d", t.x, t.y[0], t.y[1]);
    outer = '{default:6};
    $display("nested %0d %0d %0d", outer.child.x,
             outer.child.y[0], outer.child.y[1]);
    matrix = '{default:7};
    $display("matrix %0d %0d %0d %0d %0d %0d",
             matrix.values[0][0], matrix.values[0][1], matrix.values[0][2],
             matrix.values[1][0], matrix.values[1][1], matrix.values[1][2]);
    top_packed = '{default:5};
    $display("top-packed %0d %0d", top_packed.a, top_packed.b);
    packed_outer = '{default:5};
    $display("packed %0d %0d", packed_outer.value.a,
             packed_outer.value.b);
    source = '{default:9};
    same_type = '{default:source};
    $display("same %0d %0d", same_type.value.values[0],
             same_type.value.values[1]);
  end
endmodule
