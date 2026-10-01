// A reduction method with a `with' clause over a rand dynamic array or queue
// (IEEE 1800-2017/2023 7.12.3, 18.5.8.2): `vec.sum() with (int'(item)) == 100'
// widens each element before summing, so the 8-bit elements add to 100 instead
// of wrapping. It was "not representable", failing randomize(). A second rand
// object in the class made the whole call fail with "the complete joint
// solution set exceeds the enumeration limit".
class leaf;
  rand bit [3:0] v;
  constraint cv { v < 8; }
endclass

class with_obj;
  rand leaf kid;
  rand bit [7:0] vec[];
  rand bit [7:0] q[$];
  constraint c_vec {
    vec.size() == 4;
    vec.sum() with (int'(item)) == 100;
    foreach (vec[i]) vec[i] > 0;
  }
  constraint c_q {
    q.size() inside {[2:4]};
    q.sum() with (int'(item) * 2) == 120;
    q.xor() with (item + 1) != 0;
  }
  function new(); kid = new; endfunction
endclass

module main;
  int errors;
  bit [7:0] arr[];
  initial begin
    with_obj o;
    int sum;
    o = new;
    repeat (6) begin
      if (!o.randomize()) begin $display("FAILED randomize"); errors++; continue; end
      if (o.vec.size() != 4) begin $display("FAILED vec size"); errors++; end
      sum = 0;
      foreach (o.vec[i]) begin sum += o.vec[i]; if (o.vec[i] == 0) begin $display("FAILED zero"); errors++; end end
      if (sum != 100) begin $display("FAILED vec sum %0d", sum); errors++; end
      sum = 0;
      foreach (o.q[i]) sum += o.q[i] * 2;
      if (sum != 120) begin $display("FAILED q sum %0d", sum); errors++; end
      if (o.kid.v >= 8) begin $display("FAILED kid"); errors++; end
    end
    repeat (10) begin
      if (!std::randomize(arr) with { arr.size() == 3; arr.sum() with (int'(item)) == 500; }) begin
        $display("FAILED std::randomize"); errors++; continue;
      end
      sum = 0;
      foreach (arr[i]) sum += arr[i];
      if (sum != 500) begin $display("FAILED scope sum %0d", sum); errors++; end
    end
    if (errors == 0) $display("PASSED");
  end
endmodule
