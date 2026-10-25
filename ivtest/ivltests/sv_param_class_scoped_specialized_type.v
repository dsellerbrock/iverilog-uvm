module sv_param_class_scoped_specialized_type;
  virtual class C #(parameter type T = logic, parameter int SIZE = 1);
    typedef T t_vector[SIZE];
  endclass

  C#(bit, 3)::t_vector v;

  initial begin
    if ($bits(v) != 3)
      $fatal(1, "specialized class-scoped typedef has wrong width");
    v[0] = 1'bx;
    if ($isunknown(v[0]))
      $fatal(1, "specialized class-scoped typedef has wrong element type");
    $display("PASS");
  end
endmodule
