// IEEE 1800-2017/2023 17.3, 26.3, 26.6: a checker has package identity.
package counts3361;
  int first_hits, second_hits, local_hits, module_roots;
endpackage

package first3361;
  checker c(logic first_clk, logic good);
    import counts3361::first_hits;
    a: assert property (@(posedge first_clk) good)
      else first_hits++;
  endchecker
endpackage

package second3361;
  checker c(logic second_clk, logic good);
    import counts3361::second_hits;
    first3361::c nested(.first_clk(second_clk), .good(good));
    a: assert property (@(posedge second_clk) good)
      else second_hits++;
  endchecker
endpackage

package export3361;
  import first3361::c;
  export first3361::c;
endpackage

package alias3361;
  import export3361::c;
  export export3361::c;
endpackage

interface bind_explicit3361(input logic clk);
  import first3361::c;
endinterface

interface bind_realized3361(input logic clk);
  import first3361::*;
  c seed(.first_clk(clk), .good(1'b0));
endinterface

bind bind_explicit3361 c bound_c(.first_clk(clk), .good(1'b0));
bind bind_realized3361 c bound_c(.first_clk(clk), .good(1'b0));

// A checker instance with type name c must leave this automatic root eligible.
module c;
  import counts3361::module_roots;
  initial module_roots++;
endmodule

module issue3361;
  logic clk = 0;
  bind_explicit3361 explicit_target(clk);
  bind_realized3361 realized_target(clk);

  checker c(logic local_clk);
    import counts3361::local_hits;
    a: assert property (@(posedge local_clk) 1'b0)
      else local_hits++;
  endchecker

  c local_c(.local_clk(clk));
  first3361::c first_c(.first_clk(clk), .good(1'b0));
  second3361::c second_c(.second_clk(clk), .good(1'b0));
  export3361::c exported_c(.first_clk(clk), .good(1'b0));
  alias3361::c alias_c(.first_clk(clk), .good(1'b0));

  if (1) begin : wildcard_scope
    import first3361::*;
    import alias3361::*;
    c wildcard_c(.first_clk(clk), .good(1'b0));
    import second3361::*;
    c pinned_c(.first_clk(clk), .good(1'b0));
  end

  if (1) begin : explicit_scope
    import first3361::*;
    import second3361::c;
    c explicit_c(.second_clk(clk), .good(1'b0));
  end

  initial begin
    repeat (2) begin
      #1 clk = 1;
      #1 clk = 0;
    end
    if (counts3361::first_hits != 20 || counts3361::second_hits != 4 ||
        counts3361::local_hits != 2 || counts3361::module_roots != 1)
      $fatal(1, "checker/root counts %0d %0d %0d %0d",
             counts3361::first_hits, counts3361::second_hits,
             counts3361::local_hits, counts3361::module_roots);
    $display("PASSED");
  end
endmodule
