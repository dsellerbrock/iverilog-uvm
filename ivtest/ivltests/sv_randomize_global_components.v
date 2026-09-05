// IEEE 1800-2017 18.5.9/18.5.10; IEEE 1800-2023 18.5.8/18.5.9.
// Object RNG replay: IEEE 1800-2017/2023 18.14.1/18.14.3.
class leaf;
  rand int unsigned value;
  constraint c { value inside {[0:100]}; }
endclass
class root;
  rand leaf a, b;
  function new(); a=new; b=new; endfunction
endclass
class bit_leaf;
  rand bit a, b;
endclass
class pairs;
  rand bit_leaf left, right;
  function new(); left=new; right=new; endfunction
  constraint c { left.a >= left.b; right.a == 0 || right.b == 0; }
endclass
module main;
  root r=new;
  pairs p=new;
  int counts[16];
  bit [3:0] replay[12];
  string rs, ls, cs;
  initial begin
    r.srandom(43); r.a.srandom(47); r.b.srandom(53);
    repeat (4) if (!r.randomize() || r.a.value>100 || r.b.value>100)
      $fatal(1,"independent 101-value factors failed");
    p.srandom(59); p.left.srandom(61); p.right.srandom(67);
    repeat (2700) begin
      if (!p.randomize()) $fatal(1,"independent tuple factors failed");
      if (p.left.a < p.left.b || (p.right.a && p.right.b))
        $fatal(1,"factorization lost OR or coupled hard constraints");
      counts[{p.left.a,p.left.b,p.right.a,p.right.b}]++;
    end
    foreach (counts[i]) begin
      if ((i/4)!=1 && (i%4)!=3) begin
        if (counts[i]<225 || counts[i]>375) $fatal(1,"factor product not uniform");
      end else if (counts[i]) $fatal(1,"illegal tuple selected");
    end
    rs=p.get_randstate(); ls=p.left.get_randstate(); cs=p.right.get_randstate();
    for (int i=0;i<12;i++) begin
      if (!p.randomize()) $fatal(1,"replay setup failed");
      replay[i]={p.left.a,p.left.b,p.right.a,p.right.b};
    end
    p.set_randstate(rs); p.left.set_randstate(ls); p.right.set_randstate(cs);
    for (int i=0;i<12;i++) begin
      if (!p.randomize() || replay[i]!={p.left.a,p.left.b,p.right.a,p.right.b})
        $fatal(1,"factor RNG replay changed");
    end
    $display("PASSED");
  end
endmodule
