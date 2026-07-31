// Companion to ivltests/sv_enum_packed_array_sel: the element select of
// a packed array of enums now carries the enum type, so it must be
// checked LIKE an enum -- assigning it to a DIFFERENT enum is the
// IEEE 1800-2017 6.19.3 mismatch and must be rejected. A select that
// merely dropped its typing would sail through here.
module sv_enum_packed_sel_type_mismatch;
  typedef enum logic [2:0] { A = 3'b101, B = 3'b010 } e_t;
  typedef enum logic [2:0] { C = 3'b001, D = 3'b100 } f_t;
  e_t [3:0] arr;
  f_t one;
  assign one = arr[2];
endmodule
