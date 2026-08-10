// A suffix-slice retains the complete queue type. Incompatible element types
// are rejected at elaboration rather than reaching a generic object store.
module main;
  int qi[$];
  string qs[$];

  initial begin
    qi = {1, 2, 3};
    qs = {"x", "y"};
    qi[1:$] = qs;
  end
endmodule
