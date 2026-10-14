class restricted_class_t;
endclass

class interface_class_holder #(type interface class T);
endclass

module test;
  interface_class_holder#(restricted_class_t) invalid;
endmodule
