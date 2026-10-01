class l111_rb_leaf; randc bit cyc; endclass
class l111_rb_item;
  rand bit sel, dep, other;
  rand l111_rb_leaf leaf;
  constraint link_c { dep == sel; }
  constraint order_c { solve sel before dep; }
  constraint dist1_c { other dist {0:=1,1:=1}; }
  constraint dist2_c { other dist {0:=2,1:=1}; }
  function new; leaf=new; endfunction
endclass
module sv_joint_coupled_randc_ordered_rollback;
  initial begin
    l111_rb_item a,b; string ar,br,al,bl;
    a=new; b=new; a.srandom(32'h11100002); b.srandom(32'h11100002);
    a.leaf.srandom(32'h11100003); b.leaf.srandom(32'h11100003);
    ar=a.get_randstate(); al=a.leaf.get_randstate();
    if (a.randomize()) $fatal(1,"unsupported call succeeded");
    if (a.get_randstate()!=ar || a.leaf.get_randstate()!=al)
      $fatal(1,"failed call consumed RNG state");
    a.dist2_c.constraint_mode(0); b.dist2_c.constraint_mode(0);
    if (!a.randomize() || !b.randomize()) $fatal(1,"enabled solve failed");
    if (a.sel!=b.sel || a.dep!=b.dep || a.other!=b.other || a.leaf.cyc!=b.leaf.cyc)
      $fatal(1,"rollback changed next result");
    br=b.get_randstate(); bl=b.leaf.get_randstate();
    if (a.get_randstate()!=br || a.leaf.get_randstate()!=bl)
      $fatal(1,"rollback changed next RNG state");
    $display("PASSED"); $finish(0);
  end
endmodule
