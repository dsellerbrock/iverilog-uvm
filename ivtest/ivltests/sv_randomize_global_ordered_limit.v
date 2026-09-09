// IEEE 1800-2017 18.5.10; IEEE 1800-2023 18.5.9.
class leaf;
  rand bit value;
endclass
class weighted_root;
  rand bit a, b;
  rand leaf child;
  function new(); child=new; endfunction
  constraint c { solve a before b; a dist {0:=1, 1:=2}; child.value == b; }
endclass
class capped_root;
  rand bit [10:0] value;
  rand bit tail_value;
  rand leaf child;
  int limit=1023;
  int posts;
  function new(); child=new; endfunction
  function void post_randomize(); posts++; endfunction
  constraint c {solve value before tail_value; value <= limit; tail_value == value[0]; child.value == tail_value;}
endclass
module main;
 weighted_root w=new;
 capped_root c=new;
 bit [10:0] old_value;
 bit old_tail, old_child;
 initial begin
  if(w.randomize() || w.a || w.b || w.child.value) $fatal(1,"ordered dist was accepted or changed values");
  if(!c.randomize() || c.posts!=1 || c.tail_value!=c.value[0] || c.child.value!=c.tail_value) $fatal(1,"1024 ordered tuples failed");
  old_value=c.value; old_tail=c.tail_value; old_child=c.child.value;
  c.limit=1024;
  for (int seed=0; seed<4; seed++) begin
   c.srandom(seed);
   if(c.randomize() || c.value!=old_value || c.tail_value!=old_tail || c.child.value!=old_child || c.posts!=1) $fatal(1,"ordered cap failure changed values/posts");
  end
  $display("PASSED");
 end
endmodule
