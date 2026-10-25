module sv_nba_dynamic_array_element_fail;
  int d[];
  initial begin
    d = new[2];
    d[0] <= 1;
  end
endmodule
