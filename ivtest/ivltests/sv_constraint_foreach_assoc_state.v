// IEEE1800-2017 18.3,18.5.8.1,18.5.13;2023 18.3,18.5.7.1,18.5.12.
class packet;
  rand bit value;
  int state_map[int];
  constraint c { foreach(state_map[i]) (state_map[i]==7) -> value==1; }
endclass
class xpacket;
  rand bit value;
  logic [7:0] state_map[string];
  constraint c { foreach(state_map[i]) (value==0 || state_map[i]==7); }
endclass
module main;
  packet req; xpacket xreq;
  initial begin
    req=new; req.state_map[-4]=7; req.state_map[99]=12; req.value=0;
    if(!req.randomize() || req.value!=1 || req.state_map[-4]!=7 || req.state_map[99]!=12)
      $fatal(1,"associative state guard");
    xreq=new; xreq.value=1; xreq.state_map["x"]='x;
    if(xreq.randomize() || xreq.value!=1 || xreq.state_map["x"]!==8'hxx)
      $fatal(1,"associative X state accepted or rollback");
    $display("PASSED");
  end
endmodule
