module p06_23a;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  typedef bit node;
  typedef bit signed [7:0] BYTE;  typedef bit signed [0:7] ETYB;  typedef byte signed MY_CHAR;
  typedef byte MEM_BYTES [256];  typedef bit signed [7:0] MY_MEM_BYTES [256];
  typedef logic [1:0][3:0] NIBBLES;  typedef logic [7:0] MY_BYTE;
  typedef struct packed {int A; int B;} AB_t;  typedef struct packed {int A; int B;} otherAB_t;
  AB_t ab1, ab2;  otherAB_t ab3;
  struct packed {int A; int B;} an1, an2;  struct packed {int A; int B;} an3;
  bit [12:0] A_bus, B_bus;
  logic [3:0] a = 4'h1, b = 4'h2;  int i = 5, cnt = 0, e;  logic [15:0] v = 16'hABCD;
  function int f(); cnt++; return 0; endfunction
  localparam type T = type(bit [12:0]);
  parameter type bus_t = type(A_bus);
  var type(a + b) c, d;
  var type(f()) z;
  class W #(type TT = int); function int w(); return $bits(TT); endfunction endclass
  W #(type(A_bus)) w1 = new;
  generate case (type(bus_t))
    type(bit[12:0]): initial $display("GEN bit13");
    type(real): initial $display("GEN real");
  endcase endgenerate
  initial begin
    ck("var_type_width", $bits(c) == 4 && $bits(d) == 4);
    e = type(i + 3)'(v);  ck("type_cast", e == 43981);
    ck("operand_not_evaluated", cnt == 0);
    ck("local_type_param", $bits(T) == 13 && $bits(bus_t) == 13);
    ck("cmp_same", type(A_bus) == type(B_bus));
    ck("cmp_typedef_alias", type(node) == type(bit) && type(MY_CHAR) == type(byte));
    ck("cmp_bitvec_predefined", type(BYTE) == type(byte) && type(int) == type(bit signed [31:0]));
    ck("cmp_range_direction", type(ETYB) != type(byte));
    ck("cmp_anon_struct", type(an1) == type(an2) && type(an1) != type(an3));
    ck("cmp_typedef_struct", type(ab1) == type(ab2) && type(ab3) != type(ab1));
    ck("cmp_array_match", type(MEM_BYTES) == type(MY_MEM_BYTES));
    ck("cmp_array_nomatch", type(NIBBLES) != type(MY_BYTE));
    ck("cmp_builtin_distinct", type(int) != type(shortint) && type(logic [3:0]) != type(bit [3:0]));
    ck("type_in_class_param", w1.w() == 13);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
