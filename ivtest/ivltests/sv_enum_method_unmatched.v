// IEEE 1800-2017 and IEEE 1800-2023 6.19.5.3, 6.19.5.4, 6.19.5.6, Table 6-7.
module main;
  typedef enum bit [1:0] {B_ONE = 1, B_TWO = 2} b_t;
  typedef enum logic [1:0] {L_ZERO = 0, L_TWO = 2} l_t;
  typedef enum bit {ONLY = 1} single_t;
  single_t single_value;
  typedef enum bit [2:0] {T_ONE = 1, T_THREE = 3, T_SIX = 6} three_t;
  three_t three;
  b_t b;
  l_t l;
  integer count;
  initial begin
    for (count = 0; count <= 4; count = count + 1) begin
    b = b_t'(3);
    l = l_t'(1);
    if (b.name() != "" || l.name() != "") $fatal(1, "unmatched name");
    if (b.next(count) !== 2'b00 || b.prev(count) !== 2'b00)
      $fatal(1, "unmatched two-state count %0d", count);
    if (l.next(count) !== 2'bxx || l.prev(count) !== 2'bxx)
      $fatal(1, "unmatched four-state count %0d", count);
    b = B_ONE;
    l = L_TWO;
    if (b.next(0) !== B_ONE || b.prev(2) !== B_ONE ||
        l.next(2) !== L_TWO || l.prev(0) !== L_TWO)
      $fatal(1, "valid full-cycle methods");
    single_value = ONLY;
    if (single_value.next(count) !== ONLY || single_value.prev(count) !== ONLY)
      $fatal(1, "single-member methods");
    end
    three = three_t'(2);
    if (three.name() != "" || three.next(0) !== 3'b0 ||
        three.prev(3) !== 3'b0 || three.next(4) !== 3'b0 ||
        three.prev(32'hffffffff) !== 3'b0 || three.next(-1) !== 3'b0)
      $fatal(1, "unmatched three-member unsigned count");
    $display("PASSED");
  end
endmodule
