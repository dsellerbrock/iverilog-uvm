module sv_param_class_scoped_static_lvalue_recursive;
  class leaf;
    int value;

    function int get();
      return value;
    endfunction
  endclass

  class payload;
    leaf child;
    int words[3];
  endclass

  class wrapper #(int VALUE = 1);
    static payload obj;
    static payload objects[2];
    static int matrix[2][3];
    static logic [31:0] bits;
    static int queue_values[$];

    static function void set_self_value(int value);
      wrapper::obj.child.value = value;
    endfunction
  endclass

  typedef wrapper default_wrapper;
  class holder #(type T = wrapper);
    static function void set_type_value(int value);
      T::obj.child.value = value;
    endfunction
  endclass
  payload default_obj;
  payload alternate_obj;
  leaf default_leaf;
  leaf alternate_leaf;
  int queue_offset;

  initial begin
    default_obj = new;
    alternate_obj = new;
    default_leaf = new;
    alternate_leaf = new;
    default_obj.child = default_leaf;
    alternate_obj.child = alternate_leaf;

    wrapper#()::obj = default_obj;
    wrapper#(2)::obj = alternate_obj;
    wrapper#()::objects[1] = default_obj;
    wrapper#(2)::objects[1] = alternate_obj;

    wrapper#()::obj.child.value = 101;
    wrapper#()::obj.words[2] = 102;
    wrapper#()::objects[1].child.value = 103;
    wrapper#()::matrix[1][2] = 104;

    wrapper#(2)::obj.child.value = 201;
    wrapper#(2)::obj.words[2] = 202;
    wrapper#(2)::objects[1].child.value = 203;
    wrapper#(2)::matrix[1][2] = 204;

    default_wrapper::obj.child.value = 105;
    wrapper#()::set_self_value(106);
    holder#()::set_type_value(107);

    wrapper#()::bits = '0;
    wrapper#()::bits[3] = 1'b1;
    wrapper#()::bits[7:4] = 4'ha;
    wrapper#()::bits[8 +: 4] = 4'h5;
    wrapper#()::bits[15 -: 4] = 4'hc;
    wrapper#(2)::bits = 32'h2468_ace0;

    wrapper#()::queue_values = '{10, 20, 30, 40};
    wrapper#(2)::queue_values = '{100, 200, 300, 400};
    queue_offset = 1;
    wrapper#()::queue_values[$] = 41;
    wrapper#()::queue_values[$-queue_offset] = 31;
    wrapper#(2)::queue_values[$] = 401;
    wrapper#(2)::queue_values[$-queue_offset] = 301;

    if (default_wrapper::obj.child.value !== 107
        || default_wrapper::obj.words[2] !== 102
        || default_wrapper::objects[1].child.value !== 107
        || default_wrapper::matrix[1][2] !== 104
        || default_wrapper::bits !== 32'h0000_c5a8
        || default_wrapper::queue_values[2] !== 31
        || default_wrapper::queue_values[3] !== 41
        || wrapper#()::obj.child.get() !== 107
        || wrapper#(2)::obj.child.value !== 203
        || wrapper#(2)::obj.child.get() !== 203
        || wrapper#(2)::obj.words[2] !== 202
        || wrapper#(2)::objects[1].child.value !== 203
        || wrapper#(2)::matrix[1][2] !== 204
        || wrapper#(2)::bits !== 32'h2468_ace0
        || wrapper#(2)::queue_values[2] !== 301
        || wrapper#(2)::queue_values[3] !== 401)
      $fatal(1, "recursive scoped l-value or specialization mismatch");
    $display("PASSED");
  end
endmodule
