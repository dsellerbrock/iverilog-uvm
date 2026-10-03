// IEEE 1800-2017 21.2.1.3: %p formats a selected unpacked-struct value.
// Nested associative-array selection must pass the struct value, not its
// unpacked-array backing store, to the VPI formatter.
module sv_nested_assoc_struct_display;
  typedef struct { int code; string message; } log_t;
  log_t logs[string][int];
  string rendered;

  initial begin
    logs["image"][7] = '{code:12, message:"ok"};
    rendered = $sformatf("%p", logs["image"][7]);
    if (rendered == "'{code:12, message:\"ok\"}") $display("PASSED");
    else $display("FAILED: %s", rendered);
  end
endmodule
