module issue2733_offset_regression;
  class box; logic [31:0] values[$]; endclass
  box boxes[$], other[$], b, c; int calls, nested_calls, offsets, off; logic [31:0] x, unknown;
  function automatic int ri(); calls++; return 0; endfunction
  function automatic int ni(); nested_calls++; return 0; endfunction
  function automatic int di(); offsets++; return off; endfunction
  function automatic int mutate(); offsets++; b.values.push_back(40); return 1; endfunction
  initial begin
    b=new; b.values={10,20,30}; boxes={b};
    calls=0; x=boxes[ri()].values[$-1];
    if (x!==20 || calls!=1) $fatal(1,"constant x=%h calls=%0d",x,calls);
    off=1; calls=0; offsets=0; x=boxes[ri()].values[$-di()];
    if (x!==20 || calls!=1 || offsets!=1) $fatal(1,"dynamic x=%h calls=%0d offsets=%0d",x,calls,offsets);
    calls=0; offsets=0; x=boxes[ri()].values[$-mutate()];
    if (x!==20 || calls!=1 || offsets!=1 || b.values.size()!=4) $fatal(1,"mutation x=%h calls=%0d offsets=%0d",x,calls,offsets);
    void'(b.values.pop_back());
    c=new; c.values={0,1}; other={c}; calls=0; nested_calls=0;
    x=boxes[ri()].values[$-other[ni()].values[$-1]];
    if (x!==30 || calls!=1 || nested_calls!=1) $fatal(1,"nested x=%h calls=%0d nested=%0d",x,calls,nested_calls);
    off=3; calls=0; offsets=0; x=boxes[ri()].values[$-di()];
    if (x!==32'bx || calls!=1 || offsets!=1) $fatal(1,"outside x=%h calls=%0d offsets=%0d",x,calls,offsets);
    unknown='x; calls=0; x=boxes[ri()].values[$-unknown];
    if (x!==32'bx || calls!=1) $fatal(1,"X offset x=%h calls=%0d",x,calls);
    unknown='z; calls=0; x=boxes[ri()].values[$-unknown];
    if (x!==32'bx || calls!=1) $fatal(1,"Z offset x=%h calls=%0d",x,calls);
    calls=0; x=boxes[ri()].values[boxes[ri()].values.size()-2];
    if (x!==20 || calls!=2) $fatal(1,"explicit receiver x=%h calls=%0d",x,calls);
    b.values.delete(); calls=0; x=boxes[ri()].values[$-1];
    if (x!==32'bx || calls!=1) $fatal(1,"empty x=%h calls=%0d",x,calls);
    $display("PASS");
  end
endmodule

module issue2733_offset_types;
 class box; string names[$]; real reals[$]; endclass
 box boxes[$], b; int calls;
 function automatic int ri(); calls++; return 0; endfunction
 initial begin
  b=new; b.names={"a","b","c"}; b.reals={1.0,2.0,3.0}; boxes={b};
  calls=0; if(boxes[ri()].names[$-1]!="b" || calls!=1) $fatal(1,"string calls=%0d",calls);
  calls=0; if(boxes[ri()].reals[$-1]!=2.0 || calls!=1) $fatal(1,"real calls=%0d",calls);
  b.names.delete(); b.reals.delete();
  calls=0; if(boxes[ri()].names[$-1] != "" || calls!=1) $fatal(1,"empty string calls=%0d",calls);
  calls=0; if(boxes[ri()].reals[$-1] != 0.0 || calls!=1) $fatal(1,"empty real calls=%0d",calls);
  $display("PASS");
 end
endmodule

module issue2733_offset_object;
 class item; int n; endclass
 class box; item values[$]; endclass
 box boxes[$], b; item p,q,r; int calls;
 function automatic int ri(); calls++; return 0; endfunction
 initial begin
  b=new; p=new; q=new; p.n=4; q.n=7; b.values={p,q}; boxes={b};
  calls=0; r=boxes[ri()].values[$-1];
  if (calls!=1 || r!=p || r.n!=4) $fatal(1,"object select calls=%0d",calls);
  b.values.delete(); calls=0; r=boxes[ri()].values[$-1];
  if (calls!=1 || r!=null) $fatal(1,"empty object calls=%0d",calls);
  $display("PASS");
 end
endmodule

module widths;
 class box; logic [7:0] q[$]; endclass
 box a[$],b; logic [7:0] x; logic [63:0] wide; logic signed [63:0] neg; int calls;
 function automatic int ix(); calls++; return 0; endfunction
 initial begin
  b=new; b.q={8'h11,8'h22,8'h33}; a={b};
  wide=64'd1; calls=0; x=a[ix()].q[$-wide]; if(x!==8'h22 || calls!=1) $fatal(1,"wide x=%h calls=%0d",x,calls);
  wide=64'h1_0000_0000; calls=0; x=a[ix()].q[$-wide]; if(x!==8'hxx || calls!=1) $fatal(1,"large x=%h calls=%0d",x,calls);
  neg=-1; calls=0; x=a[ix()].q[$-neg]; if(x!==8'hxx || calls!=1) $fatal(1,"negative x=%h calls=%0d",x,calls);
  $display("PASS");
 end
endmodule

module issue2733_offset_struct;
 typedef struct { int n; } S;
 class box; S q[$]; endclass
 box a[$],b; S v; int calls;
 function automatic int ix(); calls++; return 0; endfunction
 initial begin b=new; v.n=4; b.q.push_back(v); v.n=7; b.q.push_back(v); a={b};
  calls=0; v=a[ix()].q[$-1]; if(calls!=1 || v.n!=4) $fatal(1,"value %0d %0d",v.n,calls);
  v.n=11; if(b.q[0].n!=4) $fatal(1,"alias"); $display("PASS"); end
endmodule

module issue2733_offset_all;
  issue2733_offset_regression a();
  issue2733_offset_types b();
  issue2733_offset_object c();
  widths d();
  issue2733_offset_struct e();
endmodule
