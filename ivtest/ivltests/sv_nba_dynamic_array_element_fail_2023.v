module sv_nba_dynamic_array_element_fail_2023;
  int d[];
  initial begin
    d = new[2];
    d[0] <= 1;
  end
endmodule
