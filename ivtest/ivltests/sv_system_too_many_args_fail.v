module main;
  int status;

  initial begin
    $system("exit 0", "exit 7");
    status = $system("exit 0", "exit 7");
  end
endmodule
