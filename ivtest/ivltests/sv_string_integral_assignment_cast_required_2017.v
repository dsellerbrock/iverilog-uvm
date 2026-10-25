// IEEE 1800-2017/2023 6.16: assigning an integral value to string
// requires an explicit string cast.
module sv_string_integral_assignment_cast_required;
  string s;
  initial s = 8'h41;
endmodule
