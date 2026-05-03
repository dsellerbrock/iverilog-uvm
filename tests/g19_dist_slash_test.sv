// G19: dist :/ weighted bins hard constraint (values must be in the set)
// Note: soft-weight distribution quality (proportional sampling) is a
// known limitation of the Z3 soft-assert approach; values ARE constrained
// to the correct set but may not follow the exact :/ ratio.
class Foo;
  rand int x;
  constraint c { x dist {0:/40, 1:/40, 2:/20}; }
endclass

module top;
  Foo f;
  int cnt0, cnt1, cnt2, out_of_range;
  initial begin
    f = new;
    cnt0 = 0; cnt1 = 0; cnt2 = 0; out_of_range = 0;
    repeat (30) begin
      void'(f.randomize());
      case (f.x)
        0: cnt0++;
        1: cnt1++;
        2: cnt2++;
        default: out_of_range++;
      endcase
    end
    $display("dist :/ counts: x=0:%0d x=1:%0d x=2:%0d out_of_range:%0d",
             cnt0, cnt1, cnt2, out_of_range);
    // Hard constraint: all values must be in {0,1,2}
    if (out_of_range == 0 && (cnt0 + cnt1 + cnt2) == 30)
      $display("G19_PASS: dist :/ constrains values to correct set");
    else
      $display("FAIL: dist :/ produced out-of-range values");
    $finish;
  end
endmodule
