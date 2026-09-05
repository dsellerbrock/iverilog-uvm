// IEEE 1800-2017 18.3/18.5.4/18.5.9/18.5.10/18.6.1/18.6.3;
// IEEE 1800-2023 18.3/18.5.3/18.5.8/18.5.9/18.6.1/18.6.3.
// Unsupported distributions and coupled factors fail without partial writeback.
class leaf;
  rand bit [9:0] value;
endclass
class coupled;
  rand leaf child;
  rand bit value;
  int posts;
  function new(); child=new; child.value=13; value=1; endfunction
  function void post_randomize(); posts++; endfunction
  constraint c { value==0 || child.value==0; }
endclass
class bad_weight;
  rand leaf child;
  rand bit value=1;
  rand bit weight;
  int posts;
  function new(); child=new; endfunction
  function void post_randomize(); posts++; endfunction
  constraint c { value dist {0 := (weight+1), 1 := 1}; }
endclass
class x_weight;
  rand leaf child;
  rand bit value=1;
  integer weight='x;
  int posts;
  function new(); child=new; endfunction
  function void post_randomize(); posts++; endfunction
  constraint c { value dist {0 := weight, 1 := 1}; }
endclass
class soft_dist;
  rand leaf child;
  rand bit [1:0] value;
  function new(); child=new; endfunction
  constraint c { value==2; soft value dist {0 := 1, 1 := 1}; }
endclass
class partial_range;
  rand leaf child;
  rand int value;
  function new(); child=new; endfunction
  constraint c { value > 101; value dist {[100:102] := 1, 103 := 1}; }
endclass
class coupled_dist;
  rand leaf child;
  rand bit value;
  function new(); child=new; endfunction
  constraint c { child.value==value; value dist {0:=1,1:=2}; child.value dist {0:=2,1:=1}; }
endclass
module main;
  coupled c=new;
  bad_weight b=new;
  x_weight x=new;
  soft_dist s=new;
  partial_range p=new;
  coupled_dist d=new;
  initial begin
    if (c.randomize() || c.value!=1 || c.child.value!=13 || c.posts)
      $fatal(1,"coupled OR limit split or rollback lost");
    if (b.randomize() || b.value!=1 || b.posts) $fatal(1,"active weight admitted");
    b.value.rand_mode(0);
    if (b.randomize() || b.value!=1 || b.posts) $fatal(1,"inactive subject hid active weight");
    x.value.rand_mode(0);
    if (x.randomize() || x.value!=1 || x.posts) $fatal(1,"inactive subject hid X weight");
    if (s.randomize()) $fatal(1,"discarded soft dist silently sampled");
    if (p.randomize()) $fatal(1,"unproved range-exclusion policy admitted");
    if (d.randomize()) $fatal(1,"coupled distributions independently sampled");
    $display("PASSED");
  end
endmodule
