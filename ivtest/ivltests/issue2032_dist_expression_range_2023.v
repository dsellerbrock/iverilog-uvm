class issue2032_item;
  rand bit [9:0] value;
  constraint distribution_c {
    (~value) dist {[10'd0:10'd300] :/ 1};
  }
endclass

module test;
  issue2032_item item;
  int succeeded;
  initial begin
    item = new;
    repeat (50) begin
      if (!item.randomize())
        $fatal(1, "dist randomize failed");
      if ((~item.value) > 10'd300)
        $fatal(1, "dist result outside [0:300]");
      succeeded++;
    end
    if (succeeded != 50)
      $fatal(1, "expected 50 successful randomizations, got %0d", succeeded);
    $display("PASSED");
  end
endmodule
