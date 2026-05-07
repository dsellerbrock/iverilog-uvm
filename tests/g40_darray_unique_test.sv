// G40: unique() and unique_index() on dynamic arrays
module g40_darray_unique_test;
  initial begin
    int da[];
    int u[];
    int ui[];

    da = '{3, 1, 2, 1, 3, 4};

    u  = da.unique();
    ui = da.unique_index();

    if (u.size() == 4 && ui.size() == 4) begin
      $display("PASS: unique=%0d unique_index=%0d", u.size(), ui.size());
    end else begin
      $display("FAIL: unique=%0d (exp 4) unique_index=%0d (exp 4)", u.size(), ui.size());
    end
  end
endmodule
