module array_query_dynamic_type_err;
  typedef int DT[];
  initial $display("%0d", $size(DT));
endmodule
