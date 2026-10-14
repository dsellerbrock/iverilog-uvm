typedef enum logic { ZERO, ONE } restricted_enum_t;

class struct_holder #(type struct T);
endclass

module test;
  struct_holder#(restricted_enum_t) invalid;
endmodule
