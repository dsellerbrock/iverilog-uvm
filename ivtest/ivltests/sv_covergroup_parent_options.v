class wrap;
 int weight;
 int inst;
 covergroup cg with function sample(int v);
   option.weight=weight;
   option.get_inst_coverage=inst;
   cp: coverpoint v { bins b[]={[0:1]}; }
 endgroup
 function new(int w,int i); weight=w; inst=i; cg=new; endfunction
endclass
module test;
 wrap a,b;
 initial begin
  a=new(1,0); b=new(3,1); a.cg.sample(0);

  if(b.cg.option.weight!=3 || b.cg.option.get_inst_coverage!=1 || a.cg.get_coverage()!=12.5) $fatal(1,"parent options");
  b.weight=99; b.inst=0;
  if(b.cg.option.weight!=3 || b.cg.option.get_inst_coverage!=1) $fatal(1,"options not frozen at construction");
  b.cg.option.weight=1;
  b.cg=b.cg;
  if(b.cg.option.weight!=1 || a.cg.get_coverage()!=25.0) $fatal(1,"parent relink reset procedural weight");
  if($get_coverage()!=25.0) $fatal(1,"ordinary wrapper affected type coverage");
  $display("PASSED");
 end
endmodule
