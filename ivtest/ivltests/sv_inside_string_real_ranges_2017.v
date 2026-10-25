// IEEE 1800-2017 11.4.13, 6.16: string ranges use lexical ordering;
// real ranges use the real relational operators.
module sv_inside_string_real_ranges_2017;
  string text;

  task automatic check(input string label, input logic got,
                       input logic expected);
    if (got !== expected) begin
      $display("FAILED -- %s: got %b expected %b", label, got, expected);
      $finish(1);
    end
  endtask

  initial begin
    text = "read";
    check("string above range", text inside {["a":"m"]}, 0);
    check("string inside range", "b" inside {["a":"m"]}, 1);
    check("string lower endpoint", "a" inside {["a":"m"]}, 1);
    check("string upper endpoint", "m" inside {["a":"m"]}, 1);
    check("string below range", "0" inside {["a":"m"]}, 0);
    check("real above range", 5.5 inside {[1.0:4.0]}, 0);
    check("real inside range", 2.5 inside {[1.0:4.0]}, 1);
    check("real endpoint", 4.0 inside {[1.0:4.0]}, 1);
    $display("PASSED");
  end
endmodule
