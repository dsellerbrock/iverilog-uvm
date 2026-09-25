class item;
  rand bit [3:0] clen;
endclass
class owner;
  item req, alt, other;
  function int run_bare();
    req.clen = 0;
    return req.randomize() with { clen == 12; };
  endfunction
  function int run_self();
    req.clen = 0;
    return req.randomize() with { req.clen == 12; };
  endfunction
  function int run_same();
    req.clen = 0;
    alt = req;
    return alt.randomize() with { req.clen == 12; };
  endfunction
  function int run_other();
    other.clen = 0;
    return alt.randomize() with { other.clen == 12; };
  endfunction
endclass
module top;
  owner o;
  initial begin
    int ok;
    o = new;
    o.req = new;
    o.alt = o.req;
    o.other = new;
    ok = o.run_bare();
    $display("bare ok=%0d clen=%0d", ok, o.req.clen);
    if (!ok || o.req.clen != 12) $fatal(1, "bare not solved");
    ok = o.run_self();
    $display("self ok=%0d clen=%0d", ok, o.req.clen);
    if (!ok || o.req.clen != 12) $fatal(1, "self not solved");
    ok = o.run_same();
    $display("same ok=%0d clen=%0d", ok, o.req.clen);
    if (!ok || o.req.clen != 12) $fatal(1, "alias not solved");
    if (o.run_other()) $fatal(1, "distinct object accepted");
    $display("PASSED");
  end
endmodule
