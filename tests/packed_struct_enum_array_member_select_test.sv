module packed_struct_enum_array_member_select_test;
  typedef enum logic [3:0] {
    MuBiTrue  = 4'h6,
    MuBiFalse = 4'h9
  } mubi4_t;

  typedef struct packed {
    mubi4_t [1:0] resets;
  } reset_bundle_t;

  wire reset_bundle_t bundle;
  wire mubi4_t copied0;
  wire mubi4_t copied1;

  assign bundle = 8'h96;
  assign copied0 = bundle.resets[0];
  assign copied1 = bundle.resets[1];

  initial begin
    #1;
    $display("enum member values: bundle=%h copied0=%h copied1=%h",
             bundle, copied0, copied1);
    if (copied0 !== MuBiTrue || copied1 !== MuBiFalse)
      $fatal(1, "packed struct enum-array member select failed");
    $display("PASS: packed struct enum-array member select");
  end
endmodule
