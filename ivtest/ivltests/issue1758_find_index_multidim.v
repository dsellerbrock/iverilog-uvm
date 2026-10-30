module issue1758_find_index_multidim;
  int m2[5:4][9:8] = '{'{10, 11}, '{20, 21}};
  int ix[$];

  initial begin
    ix = m2.find_index(r) with (r[9] > 0);
    if (ix.size() != 2
        || !((ix[0] == 5 && ix[1] == 4)
             || (ix[0] == 4 && ix[1] == 5)))
      $fatal(1, "multidimensional find_index returned %p", ix);
    $display("PASSED");
  end
endmodule
