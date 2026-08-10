module sv_param_class_scoped_static_lvalue_special_rhs;
  class payload;
    int value;
    int data[];
  endclass

  class wrapper #(int VALUE = 1);
    static payload obj;
    static logic driven;
  endclass

  typedef wrapper default_wrapper;
  logic source;

  initial begin
    wrapper#()::obj = new;
    wrapper#()::obj.data = new[3];
    wrapper#()::obj.value = 11;
    wrapper#()::obj.data[2] = 12;

    wrapper#(2)::obj = new;
    wrapper#(2)::obj.data = new[2];
    wrapper#(2)::obj.value = 21;
    wrapper#(2)::obj.data[1] = 22;

    wrapper#(2)::driven = 1'b1;
    source = 1'b0;
    assign wrapper#()::driven = source;
    #1;
    if (default_wrapper::driven !== 1'b0)
      $fatal(1, "procedural assign initial drive mismatch");
    source = 1'b1;
    #1;
    if (default_wrapper::driven !== 1'b1)
      $fatal(1, "procedural assign update mismatch");
    deassign wrapper#()::driven;
    wrapper#()::driven = 1'b0;

    if (default_wrapper::obj.value !== 11
        || default_wrapper::obj.data[2] !== 12
        || default_wrapper::driven !== 1'b0
        || wrapper#(2)::obj.value !== 21
        || wrapper#(2)::obj.data[1] !== 22
        || wrapper#(2)::driven !== 1'b1)
      $fatal(1, "special RHS or specialization mismatch");
    $display("PASSED");
  end
endmodule
