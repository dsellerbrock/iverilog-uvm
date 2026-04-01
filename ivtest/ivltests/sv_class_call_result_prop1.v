module test;
  class item_t;
    int value;

    function new(int value);
      this.value = value;
    endfunction
  endclass

  class holder_t;
    item_t item;

    function new(int value);
      item = new(value);
    endfunction

    function item_t get_item();
      return item;
    endfunction
  endclass

  initial begin
    holder_t holder;

    holder = new(42);

    if (holder.get_item().value != 42) begin
      $display("FAILED: wrong call-result member value %0d",
               holder.get_item().value);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
