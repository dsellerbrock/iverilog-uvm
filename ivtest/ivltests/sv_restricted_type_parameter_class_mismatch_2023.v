interface class restricted_interface_class_t;
  pure virtual function void run();
endclass

class class_holder #(type class T);
endclass

module test;
  class_holder#(restricted_interface_class_t) invalid;
endmodule
