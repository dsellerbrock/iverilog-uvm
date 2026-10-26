module issue1169_std_randomize_no_args_2017;
  int a;

  initial begin
    a = 7;
    if (!std::randomize() || a != 7)
      $fatal(1, "empty checker changed state or failed");
    $display("PASSED");
  end
endmodule
