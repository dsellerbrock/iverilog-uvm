module p21_disp_io;
  integer fd, fd2, e;
  string s, msg;

  initial begin
    $display(8'd255);
    $displayh(8'd255);
    $displayb(4'b10x1);
    $displayo(6'o17);
    $write("a");
    $write("b\n");
    $display("x",,"y");
    $display;

    fd = $fopen("p21_t.txt", "w");
    $fwrite(fd, "abc\n");
    $fflush(fd);
    fd2 = $fopen("p21_t.txt", "r");
    e = $fgets(s, fd2);
    $display("FL %0d [%s]", e, s);
    e = $ferror(fd2, msg);
    $display("FE0 %0d [%s]", e, msg);

    fd = $fopen("/nonexistent_dir/x.txt", "r");
    $display("FO %0d", fd);
    e = $ferror(fd, msg);
    $display("FE1 %0d %0d", e != 0, msg.len() > 0);
    $fflush();
  end
endmodule
