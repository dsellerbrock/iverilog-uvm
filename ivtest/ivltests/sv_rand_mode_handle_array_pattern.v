class rand_mode_pattern_leaf;
  rand bit [3:0] value;
  int pre_count;
  constraint value_c { value == 9; }
  function void pre_randomize(); pre_count++; endfunction
endclass

class rand_mode_pattern_owner;
  rand rand_mode_pattern_leaf handles[2];
endclass

module sv_rand_mode_handle_array_pattern;
  initial begin
    rand_mode_pattern_owner pattern_owner;
    rand_mode_pattern_owner element_owner;
    rand_mode_pattern_leaf a, b, c, d;

    pattern_owner = new;
    element_owner = new;
    a = new;
    b = new;
    c = new;
    d = new;

    pattern_owner.handles = '{a, b};
    element_owner.handles[0] = c;
    element_owner.handles[1] = d;
    pattern_owner.handles[0].rand_mode(0);
    element_owner.handles[0].rand_mode(0);

    if (pattern_owner.handles[0].rand_mode() !== 0
        || pattern_owner.handles[1].rand_mode() !== 1)
      $fatal(1, "assignment pattern changed the wrong handle mode");
    if (!pattern_owner.randomize() || !element_owner.randomize())
      $fatal(1, "class-handle array randomization failed");

    if ({a.value, b.value, a.pre_count, b.pre_count} !== {4'd0, 4'd9, 32'd0, 32'd1})
      $fatal(1, "pattern result %0d %0d | %0d %0d",
             a.value, b.value, a.pre_count, b.pre_count);
    if ({c.value, d.value, c.pre_count, d.pre_count} !== {4'd0, 4'd9, 32'd0, 32'd1})
      $fatal(1, "element assignment control failed");
    $display("PASSED");
  end
endmodule
