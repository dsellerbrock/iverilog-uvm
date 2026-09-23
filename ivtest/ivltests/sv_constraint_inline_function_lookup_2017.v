class cfg_t;
 int state;
 function int value();return state;endfunction
endclass
class packet;
 rand int n;
 cfg_t cfg;
endclass
class owner;
 cfg_t cfg;
 task run;
  packet req=new;
  cfg=new;cfg.state=4;req.cfg=new;req.cfg.state=7;
  if(!req.randomize() with {n==cfg.value();}) $fatal(1,"target method solve");
  if(req.n!=7) $fatal(1,"target-first lookup lost");
  if(!req.randomize() with {n==local::cfg.value();}) $fatal(1,"caller method solve");
  if(req.n!=4) $fatal(1,"explicit caller lookup lost");
  $display("PASS function receiver collision");
 endtask
endclass
module top;owner o;initial begin o=new;o.run;end endmodule
