class item;
  rand bit [31:0] value;
endclass
module test;
  item a,b;
  process p;
  int unsigned root_value, fork_value, a_first;
  initial begin
    root_value=$urandom; a=new; b=new;
    if(!a.randomize()) $fatal(1,"randomize a");
    a_first=a.value;
    if($test$plusargs("EXTRA_A") && !a.randomize()) $fatal(1,"extra randomize a");
    if(!b.randomize()) $fatal(1,"randomize b");
    fork begin fork_value=$urandom; end join
    p=process::self(); p.srandom(32'h12345678);
    $display("tree %08x %08x %08x %08x override %08x",
      root_value,a_first,b.value,fork_value,$urandom);
  end
endmodule
