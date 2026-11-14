module issue3022_union_dynamic_good;
  typedef int dyn_t[];
  typedef union tagged { int i; dyn_t data; } tagged_t;
  typedef union { int i; bit [31:0] b; } ordinary_t;
  tagged_t a;
  ordinary_t b;
  initial begin
    b.i = 42;
    if (b.b !== 42) $fatal(1, "ordinary union failed");
    $display("PASS");
  end
endmodule
