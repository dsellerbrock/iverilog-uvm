// IEEE 1800-2017 20.18.1 and IEEE 1800-2023 20.17.1.
module main;
  string command = "exit 0";
  int status;

  initial begin
    if ($system(command) != 0)
      $fatal(1, "successful command returned failure");
    status = $system("exit 7");
    if (status == 0)
      $fatal(1, "failed command returned success");
    if ($system() == 0)
      $fatal(1, "no-argument shell probe returned failure");

    $system("exit 7");
    $display("PASSED");
  end
endmodule
