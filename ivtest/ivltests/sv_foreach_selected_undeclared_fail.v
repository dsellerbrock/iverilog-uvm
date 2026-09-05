// IEEE 1800-2017/2023 12.7.3, 23.7 and Annex A.6.8.
// missing is an index expression; only j is a foreach declaration.
module main;
  typedef struct { int values[2]; } row_t;
  row_t rows[2];
  initial begin
    foreach (rows[missing].values[j]) begin end
    $display("UNEXPECTED ACCEPT: undeclared selected prefix");
  end
endmodule
