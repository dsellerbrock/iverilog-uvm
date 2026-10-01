class l111_elem_child; rand bit child_value; endclass
class l111_elem_item;
 randc bit cyc[2]; rand bit sel,dep; rand l111_elem_child child;
 constraint d {foreach(cyc[i])cyc[i] inside {0,1};}
 constraint l {sel==cyc[0];dep==sel;}
 constraint w {sel dist {0:=1,1:=2};} constraint o {solve sel before dep;}
 function new;child=new;endfunction endclass
module sv_joint_coupled_randc_ordered_element;initial begin l111_elem_item t;bit f;t=new;t.cyc[1].rand_mode(0);
 if(!t.randomize())$fatal(1,"first");f=t.cyc[0];if(!t.randomize())$fatal(1,"second");
 if(t.cyc[0]===f||t.sel!=t.cyc[0]||t.dep!=t.sel)$fatal(1,"bad");
 $display("PASSED");$finish(0);end endmodule
