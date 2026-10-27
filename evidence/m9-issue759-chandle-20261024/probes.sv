module probe_rhs_chandle_to_int;
  int i;
  chandle ch;
  initial i = ch;
endmodule

module probe_rhs_chandle_to_bits;
  bit [63:0] bits;
  chandle ch;
  initial bits = ch;
endmodule

module probe_rhs_chandle_to_longint;
  longint unsigned value;
  chandle ch;
  initial value = ch;
endmodule

module probe_rhs_chandle_to_real;
  real value;
  chandle ch;
  initial value = ch;
endmodule

module probe_rhs_chandle_to_string;
  string value;
  chandle ch;
  initial value = ch;
endmodule

module probe_rhs_chandle_class_property;
  class holder;
    chandle h;
  endclass
  holder obj;
  int i;
  initial begin
    obj = new;
    i = obj.h;
  end
endmodule

module probe_rhs_chandle_class_method;
  class holder;
    chandle h;
    int i;
    function void copy_handle_to_int();
      i = h;
    endfunction
  endclass
  holder obj;
  initial begin
    obj = new;
    obj.copy_handle_to_int();
  end
endmodule

module probe_compound_chandle_to_int;
  int i;
  chandle ch;
  initial i += ch;
endmodule

module probe_valid_chandle_assignments;
  chandle a, b;
  initial begin
    a = null;
    b = a;
  end
endmodule

module probe_valid_chandle_array_element;
  chandle array [2];
  chandle value;
  initial begin
    array[0] = null;
    value = array[0];
  end
endmodule

module probe_valid_chandle_function;
  chandle value;
  function automatic chandle make_handle();
    return null;
  endfunction
  initial value = make_handle();
endmodule

module probe_valid_chandle_equality;
  chandle value;
  initial if (value == null) $display("null");
endmodule

module probe_valid_integral_assignment;
  int i;
  initial i = 5;
endmodule
