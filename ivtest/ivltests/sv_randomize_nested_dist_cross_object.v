class nested_dist_leaf_2379;
  rand bit [7:0] x;
  constraint weighted_x { x dist { [0:99] :/ 1, [100:199] :/ 3 }; }
endclass

class nested_dist_parent_2379;
  rand nested_dist_leaf_2379 l;
  rand bit [3:0] y;
  function new; l = new; endfunction
  constraint cross_object { l.x != y; }
endclass

module main;
  nested_dist_parent_2379 a = new;
  int low_count, high_count;
  initial begin
    a.srandom(32'h2379);
    repeat (64) begin
      if (!a.randomize()) $fatal(1, "nested dist cross-object randomize failed");
      if (a.l.x > 199 || a.l.x == a.y)
        $fatal(1, "nested dist membership or cross-object constraint failed");
      if (a.l.x < 100) low_count++;
      else high_count++;
    end
    if (low_count < 7 || low_count > 25
        || high_count < 39 || high_count > 57)
      $fatal(1, "dist range weighting failed: low=%0d high=%0d",
            low_count, high_count);
    $display("PASSED");
  end
endmodule
