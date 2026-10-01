class l111_migrated_leaf; randc bit cycle; endclass
class l111_migrated_item;
 rand bit sel,dep,bridge; rand l111_migrated_leaf leaf;
 constraint d {sel dist {0:=1,1:=3};} constraint c {dep==sel;bridge==sel;leaf.cycle==bridge;}
 constraint o {solve sel before dep;} function new;leaf=new;endfunction endclass
module sv_joint_ordered_independent_randc_coupled;
 initial begin l111_migrated_item t;bit first;t=new;t.srandom(32'h11100006);t.leaf.srandom(32'h11100007);
 repeat(2) begin if(!t.randomize())$fatal(1,"first");first=t.leaf.cycle;
  if(t.sel!=t.dep||t.sel!=t.bridge||t.sel!=t.leaf.cycle)$fatal(1,"link");
  if(!t.randomize())$fatal(1,"second");if(t.leaf.cycle===first)$fatal(1,"repeat");
  if(t.sel!=t.dep||t.sel!=t.bridge||t.sel!=t.leaf.cycle)$fatal(1,"link");end
 $display("PASSED");$finish(0);end endmodule
