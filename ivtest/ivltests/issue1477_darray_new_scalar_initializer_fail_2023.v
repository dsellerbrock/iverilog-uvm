module issue1477_darray_new_scalar_initializer_fail;
  int array[];
  string words[];
  int scalar;
  function int scalar_func();
    scalar_func = 7;
  endfunction
  initial begin
    array = new[2](7);
    array = new[2](scalar);
    array = new[2](scalar_func());
    words = new[2]("A");
  end
endmodule
