module issue752_static_init_no_keyword;
  initial begin
    int x = 2;
    $display("x=%0d", x);
  end
endmodule
