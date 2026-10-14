typedef struct packed { logic flag; } restricted_struct_t;

class union_holder #(type union T);
endclass

module test;
  union_holder#(restricted_struct_t) invalid;
endmodule
