// EXPECT COMPILE ERROR: IEEE 1800-2017/2023 18.3 prohibits four-state constraint operators.
// even though procedural class-handle case equality has identity semantics.
class case_leaf;
endclass
class case_root;
  case_leaf a, b;
  constraint illegal_equal { a === b; }
  constraint illegal_unequal { a !== null; }
endclass
module main;
  case_root r;
  initial begin
    r = new;
    if (r.randomize()) $fatal(1, "illegal case equality constraint accepted");
  end
endmodule
