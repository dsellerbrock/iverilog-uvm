// IEEE 1800-2017/2023 7.8.1: a string literal wildcard index is the
// equivalent-width bit vector, so "A" and 8'h41 select the same key.
module sv_assoc_wildcard_string_index;
  int values[*];
  initial begin
    values["A"] = 2;
    $display("entries=%0d at_8'h41=%0d", values.num(), values[8'h41]);
  end
endmodule
