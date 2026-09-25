// IEEE 1800-2017 20.18.1 and IEEE 1800-2023 20.17.1 permit at most one argument.
module main;
  int status;
  initial status = $system("exit 0", "exit 7");
endmodule
