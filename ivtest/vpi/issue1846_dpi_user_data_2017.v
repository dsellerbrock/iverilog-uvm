module user_data_leaf;
  import "DPI-C" context function int check_user_data(input int phase);

  initial begin
    if (!check_user_data(0))
      $fatal(1, "svPutUserData/svGetUserData check failed");
    #1;
    if (!check_user_data(1))
      $fatal(1, "svPutUserData/svGetUserData check failed");
  end
endmodule

module issue1846_dpi_user_data;
  user_data_leaf a();
  user_data_leaf b();

  initial begin
    #3;
    $display("PASSED");
    $finish;
  end
endmodule
