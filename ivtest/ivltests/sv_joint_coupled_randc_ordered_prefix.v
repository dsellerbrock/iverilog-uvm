class l111_prefix_leaf; randc bit cyc; endclass
class l111_prefix_item;
 rand bit gate, sel, dep; rand l111_prefix_leaf leaf;
 constraint link_c { sel == (leaf.cyc ^ gate); dep == sel; }
 constraint dist_c { sel dist {0:=1,1:=3}; }
 constraint order_c { solve gate before sel; solve sel before dep; }
 function new; leaf=new; endfunction
endclass
module sv_joint_coupled_randc_ordered_prefix;
 initial begin l111_prefix_item t; bit first; t=new; t.srandom(32'h11100004); t.leaf.srandom(32'h11100005);
  if(!t.randomize()) $fatal(1,"first failed"); first=t.leaf.cyc;
  if(t.sel!=(t.leaf.cyc^t.gate)||t.dep!=t.sel)$fatal(1,"bad first fiber");
  if(!t.randomize()) $fatal(1,"second failed");
  if(t.leaf.cyc===first||t.sel!=(t.leaf.cyc^t.gate)||t.dep!=t.sel)$fatal(1,"bad second fiber");
  $display("PASSED"); $finish(0); end
endmodule
