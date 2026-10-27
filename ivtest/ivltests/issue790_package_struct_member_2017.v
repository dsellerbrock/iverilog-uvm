package A; endpackage
module issue790_package_struct_member;
  typedef struct {bit A, B;} S;
  S data;
  initial $display("PASSED");
endmodule
