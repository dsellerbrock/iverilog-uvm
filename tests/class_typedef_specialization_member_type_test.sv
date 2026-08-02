// IEEE 1800-2017 6.18/8.25: a typedef of a parameterized class is a
// class scope, and a type parameter selected through that typedef denotes
// the actual specialization type. This is the shape emitted by UVM's
// factory-registration macros (`type_id::T`).
module class_typedef_specialization_member_type_test;
  class registry #(type T = int);
  endclass

  class item;
    typedef registry #(item) type_id;

    function bit build_selected_type();
      type_id::T rhs;
      rhs = new();
      return rhs != null;
    endfunction
  endclass

  item obj;
  initial begin
    obj = new();
    if (!obj.build_selected_type()) begin
      $display("CLASS TYPEDEF SPECIALIZATION MEMBER TYPE TEST: FAIL");
      $finish(1);
    end
    $display("CLASS TYPEDEF SPECIALIZATION MEMBER TYPE TEST: PASS");
    $finish(0);
  end
endmodule
