package class_typedef_parameterized_shadow_pkg;
  class selected_type #(int ID = 1);
  endclass

  class holder;
    // The local scalar typedef shadows the outer parameterized class. A class
    // resolver must follow this exact alias rather than recover by name.
    typedef int selected_type;
    selected_type#() value;
  endclass
endpackage

module sv_class_typedef_parameterized_shadow_fail;
  import class_typedef_parameterized_shadow_pkg::*;
  holder object_handle;
endmodule
