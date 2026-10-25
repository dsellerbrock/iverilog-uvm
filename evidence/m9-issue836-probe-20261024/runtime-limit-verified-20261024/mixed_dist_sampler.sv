class mixed_dist_probe;
  rand bit [3:0] mixed;
  bit [3:0] state = 1;

  function bit [3:0] state_value();
    return state;
  endfunction

  constraint mix { (mixed + state_value()) dist {7 := 1}; }
endclass

module main;
  mixed_dist_probe item = new;
  initial begin
    repeat (2) begin
      if (!item.randomize())
        $display("RANDOMIZE_FAILED mixed=%0d", item.mixed);
      else
        $display("RANDOMIZED mixed=%0d", item.mixed);
    end
  end
endmodule
