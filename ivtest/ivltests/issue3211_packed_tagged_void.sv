module issue3211_packed_tagged_void;
  typedef union tagged packed { void none; bit [7:0] value; } bit_union_t;
  typedef union tagged packed { void none; logic [3:0] value; bit flag; } logic_union_t;
  typedef union tagged packed { void empty; bit_union_t inner; } outer_union_t;
  bit_union_t b;
  logic_union_t l;
  outer_union_t outer;
  initial begin
    b = tagged value 8'ha5;
    if ($bits(b) != 9 || b[8] !== 1'b1 || b[7:0] !== 8'ha5)
      $fatal(1, "two-state packed union: %b", b);
    l = tagged value 4'b10x1;
    if ($bits(l) != 6 || l[5:4] !== 2'b01 || l[3:0] !== 4'b10x1)
      $fatal(1, "four-state packed union: %b", l);
    outer = tagged inner b;
    if ($bits(outer) != 10 || outer[9] !== 1'b1 || outer[8:0] !== b)
      $fatal(1, "nested packed union: %b", outer);
    $display("PASS");
  end
endmodule
