typedef int intP;
typedef enum fe_t;  typedef struct fs_t;  typedef union fu_t;  typedef class fc_t;  typedef fl_t;
typedef enum fe2_t;  typedef enum fe2_t;
typedef class Node;
class List; Node head; function void set(Node n); head = n; endfunction endclass
class Node; int v = 7; endclass
typedef enum {FE_A, FE_B} fe_t;  typedef struct {int a;} fs_t;  typedef union {int i; bit [31:0] b;} fu_t;
class fc_t; int z = 3; endclass
typedef int fl_t;  typedef enum {X2} fe2_t;
typedef C;
typedef C::T c_t;  c_t y;
class C; typedef int T; endclass
interface intf_i; typedef int data_t; endinterface
module sub(intf_i p); typedef p.data_t my_data_t; my_data_t data; initial $display("SUB bits=%0d", $bits(data)); endmodule
module p06_18a;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  intP a, b;  fe_t fe;  fs_t fs;  fu_t fu;  fc_t fc;  fl_t fl;  List l;  Node n;
  intf_i ii();  sub s(ii);
  initial begin
    fe = FE_B; fs.a = 3; fu.i = 5; fc = new; fl = 9; l = new; n = new; l.set(n);
    ck("typedef_int", $bits(a) == 32);
    ck("fwd_enum", fe == FE_B && $bits(fe) == 32);
    ck("fwd_struct_union", fs.a == 3 && fu.b == 5);
    ck("fwd_class", fc.z == 3 && l.head.v == 7);
    ck("fwd_generic", fl == 9);
    ck("typedef_scope_ref", $bits(y) == 32);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
