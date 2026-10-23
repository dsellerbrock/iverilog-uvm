virtual class C #(parameter type T = logic, parameter SIZE = 1);
  typedef logic [SIZE-1:0] t_vector;
  typedef T t_array [SIZE-1:0];
  typedef struct {
    t_vector m0 [2*SIZE-1:0];
    t_array m1;
  } t_struct;
endclass

typedef C#(bit,3)::t_vector scalar_t;
typedef C#()::t_vector default_t;

class U;
  C#(bit,3)::t_vector pv;
endclass

module test;
  typedef logic [7:0] t_t0;
  C#(t_t0,3)::t_vector v0;
  C#(t_t0,3)::t_array a0;
  C#(bit,4)::t_struct s0;
  scalar_t typedef_value;
  default_t default_value;
  U object;

  initial begin
    v0 = 3'b101;
    a0[0] = 8'h5a;
    s0.m0[0] = 4'ha;
    s0.m1[0] = 1'b1;
    typedef_value = 3'b011;
    default_value = 1'b1;
    object = new;
    object.pv = 3'b110;

    if ($bits(v0) != 3 || $bits(a0) != 24 || $size(a0) != 3 ||
        $bits(s0) != 36 || $bits(s0.m0) != 32 || $bits(s0.m1) != 4 ||
        $bits(default_value) != 1 || v0 != 3'b101 ||
        a0[0] != 8'h5a || s0.m0[0] != 4'ha || !s0.m1[0] ||
        typedef_value != 3'b011 || !default_value ||
        object.pv != 3'b110)
      $fatal(1, "specialized class-scoped type mismatch");

    $display("PASSED");
  end
endmodule
