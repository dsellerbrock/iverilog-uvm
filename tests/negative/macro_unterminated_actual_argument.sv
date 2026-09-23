// Negative boundary: an unterminated macro actual must remain a compile error.
`define ID(x) x
module macro_unterminated_actual_argument;
  initial $display("%0d", `ID(1);
endmodule
