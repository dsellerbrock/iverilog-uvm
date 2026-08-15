`timescale 1ns/1ps

// Annex A net_port_type has no delay slot. In non-ANSI form, an untyped
// direction declaration may be followed by the separate delayed net
// declaration used below; cover input, output and inout independently.
module delayed_io(p, en, value);
  inout p;
  input en, value;
  wire #5 p;
  assign p = en ? value : 1'bz;
endmodule

module plain_io(p, en, value);
  inout p;
  input en, value;
  wire p;
  assign p = en ? value : 1'bz;
endmodule

module delayed_input(i, seen);
  input i;
  output seen;
  wire #5 i;
  wire seen;
  assign seen = i;
endmodule

module delayed_output(o, value);
  output o;
  input value;
  wire #5 o;
  assign o = value;
endmodule

module top;
  logic e0, v0, e1, v1, ep, vp, ee, ve;
  wire no_delay;
  assign no_delay = ee ? ve : 1'bz;
  delayed_io d0(no_delay, e0, v0);
  plain_io p0(no_delay, ep, vp);
  delayed_io d1(no_delay, e1, v1);
  assign no_delay = 1'bz;

  wire #3 outer_delay;
  delayed_io d2(outer_delay, e0, v0);
  plain_io p1(outer_delay, ep, vp);
  delayed_io d3(outer_delay, e1, v1);
  assign outer_delay = ee ? ve : 1'bz;

  logic array_en, array_value, array_ext_en, array_ext_value;
  wire array_net;
  assign array_net = array_ext_en ? array_ext_value : 1'bz;
  delayed_io da[1:0](array_net, array_en, array_value);
  assign array_net = 1'bz;

  logic source_drive, source_expr, output_value;
  wire source_net, seen_net, seen_expr, output_net;
  assign source_net = source_drive;
  logic output_var;
  delayed_input di_net(source_net, seen_net);
  delayed_input di_expr(source_expr ^ 1'b0, seen_expr);
  delayed_output do_net(output_net, output_value);
  delayed_output do_var({output_var}, output_value);

  task automatic check(input logic got, input logic expected,
                       input string where);
    if (got !== expected) begin
      $display("FAILED %s t=%0t got=%b expected=%b", where, $time,
               got, expected);
      $fatal(1);
    end
  endtask

  initial begin
    e0=0; v0=0; e1=0; v1=1; ep=0; vp=0; ee=0; ve=0;
    array_en=0; array_value=0; array_ext_en=0; array_ext_value=0;
    source_drive=0; source_expr=0; output_value=0;
    #5.001;

    // External ordinary wire dominates internal wire #5 boundaries.
    e0=1; #0.001 check(no_delay, 0, "external wire dominates d0");
    e1=1; #0.001 check(no_delay, 1'bx, "two delayed instances resolve now");
    ee=1; ve=0; #0.001 check(no_delay, 1'bx, "external contention now");
    e1=0; #0.001 check(no_delay, 0, "contention recovery now");

    // The outer #3 declaration dominates both internal #5 declarations and
    // the nondelayed formal. Every contribution shares one raw resolver.
    #1 e0=0; e1=0; ee=0;
    #3.001 check(outer_delay, 1'bz, "outer initial z");
    e0=1; v0=0;
    #2.999 check(outer_delay, 1'bz, "outer delay before local driver");
    #0.002 check(outer_delay, 0, "outer delay local driver");
    e1=1; v1=1;
    #2.999 check(outer_delay, 0, "outer delay before contention");
    #0.002 check(outer_delay, 1'bx, "outer delay contention");
    e1=0;
    #3.001 check(outer_delay, 0, "outer delayed recovery");
    ep=1; vp=1;
    #3.001 check(outer_delay, 1'bx, "plain formal enters outer resolver");

    // Replicated instances and drivers declared on both sides of them must
    // not create a module-local redirect on the shared external net.
    array_en=1; array_value=0;
    #0.001 check(array_net, 0, "module-array internal delays dominated");
    array_ext_en=1; array_ext_value=1;
    #0.001 check(array_net, 1'bx, "module-array external contention");

    // Direct net ports collapse. Expression/variable connections remain
    // directional and retain the internal declaration delay.
    source_drive=1; source_expr=1; output_value=1;
    #0.001 begin
      check(seen_net, 1, "collapsed input has external delay");
      check(output_net, 1, "collapsed output has external delay");
      check(seen_expr, 0, "expression input retains internal delay");
      check(output_var, 0, "variable output retains internal delay");
    end
    #5.001 begin
      check(seen_expr, 1, "expression input delayed");
      check(output_var, 1, "variable output delayed");
    end

    $display("PASSED");
  end
endmodule
