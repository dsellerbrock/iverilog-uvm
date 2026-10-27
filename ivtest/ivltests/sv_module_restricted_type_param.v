typedef enum logic [1:0] { RED, GREEN } color_t;
typedef struct packed { logic [7:0] data; } record_t;
typedef union packed { logic [7:0] bits; record_t rec; } union_t;

class Base;
endclass

interface class Iface;
endclass

module enum_box #(parameter type enum T = color_t);
  T value;
endmodule

module struct_box #(type struct T = record_t);
  T value;
endmodule

module union_box #(type union T = union_t);
  T value;
endmodule

module class_box #(type class T = Base);
  T value;
endmodule

module iface_box #(type interface class T = Iface);
  T value;
endmodule

interface restricted_type_if #(type enum T = color_t);
  T value;
endinterface

program restricted_type_prog #(type enum T = color_t);
  T value;
endprogram

module sv_module_restricted_type_param;
  enum_box e();
  struct_box s();
  union_box u();
  class_box c();
  iface_box i();
  restricted_type_if ri();
  restricted_type_prog rp();

  initial begin
    e.value = GREEN;
    s.value = '{data: 8'hA5};
    u.value.bits = 8'h5A;
    $display("PASS");
  end
endmodule

module sv_module_restricted_type_param_bad;
  enum_box #(int) e();
endmodule
