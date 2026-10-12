// IEEE 1800-2017/2023 18.7: a caller-held method receiver can be named
// inside an inline constraint; target-class names still take precedence.
class inline_item;
  rand bit [3:0] clen;
  constraint c_clen { clen inside {[0:12]}; }
endclass

class inline_alias_group;
  inline_item req, alt;
  function new();
    req = new;
    alt = req;
  endfunction
endclass

class inline_child;
  bit [3:0] clen;
endclass

class inline_shadow_item;
  rand bit [3:0] clen;
  inline_child req;
  function new(); req = new; req.clen = 7; endfunction
endclass

class inline_owner;
  inline_item req, alt;
  inline_item other;
  inline_alias_group nested;

  function new();
    req = new;
    alt = req;
    other = new;
    nested = new;
  endfunction

  function void check();
    req.clen = 0;
    if (!req.randomize() with { req.clen == 4'd12; }
        || req.clen != 4'd12)
      $fatal(1, "owner receiver was captured instead of randomized");

    req.clen = 0;
    alt = req;
    if (!alt.randomize() with { req.clen == 4'd12; }
        || req.clen != 4'd12)
      $fatal(1, "aliased caller handle was captured as state");

    nested.req.clen = 0;
    nested.alt = nested.req;
    if (!nested.alt.randomize() with { nested.req.clen == 4'd12; }
        || nested.req.clen != 4'd12)
      $fatal(1, "nested aliased caller handle was captured as state");

    req.randomize() with { req.clen == 4'd8; };
    if (req.clen != 4'd8)
      $fatal(1, "statement-form owner receiver was not randomized");

    other.clen = 7;
    req.clen = 0;
    if (!req.randomize() with { req.clen == 4'd9; other.clen == 4'd7; }
        || req.clen != 4'd9 || other.clen != 4'd7)
      $fatal(1, "distinct caller handle was not fixed state");

    req.clen = 3;
    if (!req.randomize() with { clen == 4'd12; local::req.clen == 4'd3; }
        || req.clen != 4'd12)
      $fatal(1, "bare target or explicit caller state bound incorrectly");

    req.clen = 5;
    if (req.randomize() with { req.clen == 4'd13; } || req.clen != 4'd5)
      $fatal(1, "failed qualified solve did not roll back");

  endfunction
endclass

class inline_shadow_owner;
  inline_shadow_item req;
  function new(); req = new; endfunction
  function void check();
    req.clen = 0;
    if (!req.randomize() with { req.clen == 4'd7; clen == 4'd12; }
        || req.clen != 4'd12 || req.req.clen != 4'd7)
      $fatal(1, "target-class req did not win name lookup");
    req.randomize() with { req.clen == 4'd7; clen == 4'd11; };
    if (req.clen != 4'd11 || req.req.clen != 4'd7)
      $fatal(1, "statement-form target-class req lost name lookup");
  endfunction
endclass

module sv_randomize_owner_receiver_inline;
  inline_owner owner;
  inline_shadow_owner shadow_owner;
  initial begin
    owner = new;
    shadow_owner = new;
    owner.check();
    shadow_owner.check();
    $display("PASSED");
  end
endmodule
