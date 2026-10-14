typedef enum logic [1:0] { ENUM_ZERO, ENUM_ONE } restricted_enum_t;
typedef struct packed { logic flag; } restricted_struct_t;
typedef union packed { logic [7:0] word; logic [7:0] byte_value; } restricted_union_t;

class restricted_class_t;
endclass

interface class restricted_interface_class_t;
  pure virtual function void run();
endclass

class enum_holder #(type enum T = restricted_enum_t);
  T value;
endclass

class struct_holder #(type struct T = restricted_struct_t);
  T value;
endclass

class union_holder #(type union T = restricted_union_t);
  T value;
endclass

class class_holder #(parameter type class T = restricted_class_t);
  T value;
endclass

class interface_class_holder #(type interface class T = restricted_interface_class_t);
  T value;
endclass

module test;
  enum_holder#(restricted_enum_t) enum_value;
  enum_holder#() enum_default_value;
  struct_holder#(restricted_struct_t) struct_value;
  union_holder#(restricted_union_t) union_value;
  class_holder#(restricted_class_t) class_value;
  interface_class_holder#(restricted_interface_class_t) interface_class_value;

  initial begin
    enum_value = new;
    enum_default_value = new;
    struct_value = new;
    union_value = new;
    class_value = new;
    interface_class_value = new;
    $display("PASSED");
  end
endmodule
