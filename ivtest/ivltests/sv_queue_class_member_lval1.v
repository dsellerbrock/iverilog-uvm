module test;
  class item_t;
    int used;
  endclass

  initial begin
    item_t q[$];
    item_t item;

    item = new;
    q.push_back(item);

    q[0].used++;

    if (q[0].used !== 1) begin
      $display("FAIL used=%0d", q[0].used);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
