// IEEE 1800-2017/2023 12.6: "A constant expression pattern shall be of
// integral type." A string constant matched against a dynamic string member
// is a type error, not a syntax error or a compiler abort.
module issue3506_bad;
  typedef union tagged { void None; string Text; } u_t;
  u_t a;
  initial
    case (a) matches
      tagged Text "exact": $display("c");
      default: $display("d");
    endcase
endmodule
