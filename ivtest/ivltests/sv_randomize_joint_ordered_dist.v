class joint_ordered_dist_leaf;
  rand bit value;
endclass

class joint_ordered_dist_early;
  rand bit a;
  rand bit [1:0] data;
  rand joint_ordered_dist_leaf child;
  int posts;
  function new; child = new; endfunction
  function void post_randomize; posts++; endfunction
  constraint weights { a dist {0 := 1, 1 := 3}; }
  constraint order_c { solve a before data; }
  constraint fiber { if (!a) data == 0; child.value == data[0]; }
endclass

class joint_ordered_dist_late;
  rand bit a;
  rand bit b;
  rand joint_ordered_dist_leaf child;
  constraint weights { b dist {0 := 1, 1 := 3}; }
  constraint order_c { solve a before b; }
  constraint fiber { b <= a; child.value == b; }
  function new; child = new; endfunction
endclass

module sv_randomize_joint_ordered_dist;
  joint_ordered_dist_early early = new;
  joint_ordered_dist_late late = new;
  int early_one, early_fiber[4], late_a_one, late_b_one;
  initial begin
    early.srandom(32'h85e001); late.srandom(32'h85e002);
    repeat (4096) begin
      if (!early.randomize() || early.child.value != early.data[0])
        $fatal(1, "early ordered dist failed");
      early_one += early.a;
      if (early.a) early_fiber[early.data]++;
      if (!late.randomize() || late.b > late.a || late.child.value != late.b)
        $fatal(1, "late ordered dist failed");
      late_a_one += late.a; late_b_one += late.b;
    end
    // Exact laws: early P(a=1)=3/4 and each conditional data tuple=3/16.
    // Late P(a=1)=1/2, then P(b=1|a=1)=3/4.
    if (early_one < 2920 || early_one > 3220 || early.posts != 4096)
      $fatal(1, "early marginal %0d posts %0d", early_one, early.posts);
    foreach (early_fiber[i])
      if (early_fiber[i] < 620 || early_fiber[i] > 920)
        $fatal(1, "early conditional fiber[%0d]=%0d", i, early_fiber[i]);
    if (late_a_one < 1850 || late_a_one > 2250 ||
        late_b_one < 1350 || late_b_one > 1700)
      $fatal(1, "late marginals a=%0d b=%0d", late_a_one, late_b_one);
    $display("PASSED");
  end
endmodule
