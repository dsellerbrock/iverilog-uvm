// IEEE 1800-2017 6.19.5: an enum-valued member of a packed struct retains
// its enum type and supports the built-in name() method. The VVP expression
// for the member is a part-select, but that lowering must not erase its type.
module packed_struct_enum_method_test;
  typedef enum logic [1:0] {GCM_INIT, GCM_TEXT, GCM_TAG} phase_e;
  typedef struct packed {
    logic [3:0] count;
    phase_e phase;
  } control_t;

  control_t control;

  initial begin
    control = '{count: 4'd7, phase: GCM_TEXT};
    if (control.phase.name() == "GCM_TEXT")
      $display("PASS packed_struct_enum_method_test");
    else
      $display("FAIL packed_struct_enum_method_test got '%s'",
               control.phase.name());
    $finish;
  end
endmodule
