module p06_14c;
  typedef union tagged { void Invalid; int Valid; } vu_t;
  vu_t u;
  initial begin u=tagged Invalid; $display("TAGGED void assigned"); u=tagged Valid(5); $display("TAGGED value assigned"); end
endmodule
