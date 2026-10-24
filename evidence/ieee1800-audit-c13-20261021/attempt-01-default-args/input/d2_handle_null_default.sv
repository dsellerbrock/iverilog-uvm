module d2_handle_null_default;
  class C; int value; endclass
  task automatic t(input C h = null);
    $display("D2 null=%0d", h == null);
  endtask
  initial t();
endmodule
