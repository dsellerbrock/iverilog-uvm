// IEEE 1800-2017/2023 12.7.3, 23.7 and Annex A.6.8.
// The terminal [j] is the loop-variable list; [k,l] is not an index expression.
module main;
  typedef struct { int values[2]; } row_t;
  row_t rows[2][2];
  initial begin
    foreach (rows[k,l].values[j]) begin end
    $display("UNEXPECTED ACCEPT: comma list in selected prefix");
  end
endmodule
