// Companion to ivltests/sv_enum_packed_array_sel: teaching the element
// select of a packed array of enums to carry the enum type must NOT
// turn every slice of that array into the enum.
//
// `arr' has TWO packed dimensions of enum elements, so one index yields
// e_t[3:0] -- twelve bits, not an e_t. IEEE 1800-2017 6.19.3 still
// requires an explicit cast here, and the descent that types arr[1][2]
// has to stop short of typing arr[1].
module sv_enum_packed_sel_not_enum;
  typedef enum logic [2:0] { A = 3'b101, B = 3'b010 } e_t;
  e_t [1:0][3:0] arr;
  e_t one;
  assign one = arr[1];
endmodule
