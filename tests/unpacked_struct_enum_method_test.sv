// IEEE 1800-2017 6.19.5: enum methods on enum-valued struct members.
module unpacked_struct_enum_method_test;
  typedef enum logic [1:0] {Idle, Run, Done} state_e;
  typedef struct { state_e state; int payload; } item_t;
  item_t item;

  initial begin
    item.state = Run;
    if (item.state.name != "Run")
      $display("FAIL: enum member no-paren name got '%s'", item.state.name);
    else if (item.state.name() != "Run")
      $display("FAIL: enum member name() got '%s'", item.state.name());
    else
      $display("PASS: enum methods through unpacked struct member");
    $finish;
  end
endmodule
