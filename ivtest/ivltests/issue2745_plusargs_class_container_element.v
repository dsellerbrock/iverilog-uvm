// Issue #2745: $value$plusargs and $sscanf into an element of a class
// property's dynamic array or queue store the value. IEEE 1800-2023 21.6:
// when the plusarg is found, "the resulting value is stored in the variable
// provided"; 21.3.4.3 says the same for $sscanf. Covers a variable index,
// q[$], a nested property chain, a narrow element, string elements (also of
// a fixed-array property), an out-of-range index and a never-sized dynamic
// array (both write nothing; a read gives the element type's default, IEEE
// 1800-2023 7.4.6).
module issue2745_plusargs_class_container_element;
  class inner_t; byte bq[$] = '{8'h01, 8'h02}; string iq[$] = '{"p"}; endclass
  class c_t;
    int dq[];
    int q[$];
    int never[];
    string sd[] = '{"a", "b"};
    string sq[$] = '{"x"};
    string sa[2] = '{"m", "n"};
    inner_t in;
    function new;
      dq = '{4, 5, 6};
      q = '{1, 2, 3};
      in = new;
    endfunction
  endclass
  c_t c;
  int ok_d, ok_q, ok_l, ok_n, ok_o, ok_z, ok_miss, ok_s, n, k = 1, failed = 0;
  string text;
  initial begin
    c = new;
    ok_d = $value$plusargs("D=%d", c.dq[k]);
    ok_q = $value$plusargs("Q=%d", c.q[k + 1]);
    ok_l = $value$plusargs("L=%d", c.q[$]);
    ok_n = $value$plusargs("N=%h", c.in.bq[0]);
    ok_o = $value$plusargs("O=%d", c.dq[3]);
    ok_z = $value$plusargs("Z=%d", c.never[0]);
    ok_miss = $value$plusargs("MISSING=%d", c.dq[2]);
    ok_s = $value$plusargs("S=%s", c.sd[0]);
    n = $sscanf("9 8", "%d %d", c.dq[0], c.q[0]);
    if (ok_d != 1 || c.dq[1] != 50) begin
      $display("FAILED: dq[1] = %0d (ok=%0d)", c.dq[1], ok_d); failed++;
    end
    if (ok_q != 1 || ok_l != 1 || c.q[2] != 61) begin
      // Q=60 lands in q[2], then L=61 overwrites the same last element.
      $display("FAILED: q[2] = %0d (ok=%0d %0d)", c.q[2], ok_q, ok_l); failed++;
    end
    if (ok_n != 1 || c.in.bq[0] !== 8'h7f || c.in.bq[1] !== 8'h02) begin
      $display("FAILED: in.bq = %h %h (ok=%0d)", c.in.bq[0], c.in.bq[1], ok_n); failed++;
    end
    if (ok_o != 1 || c.dq.size() != 3) begin
      $display("FAILED: out-of-range write resized dq to %0d", c.dq.size()); failed++;
    end
    if (ok_z != 1 || c.never.size() != 0) begin
      $display("FAILED: write into a never-sized array (size %0d)", c.never.size()); failed++;
    end
    if (ok_miss != 0 || c.dq[2] != 6) begin
      $display("FAILED: a missing plusarg changed dq[2] = %0d", c.dq[2]); failed++;
    end
    if (n != 2 || c.dq[0] != 9 || c.q[0] != 8 || c.q[1] != 2) begin
      $display("FAILED: $sscanf n=%0d dq[0]=%0d q=%0d %0d", n, c.dq[0], c.q[0], c.q[1]); failed++;
    end
    if (ok_s != 1 || c.sd[0] != "hello") begin
      $display("FAILED: sd[0] = %s (ok=%0d)", c.sd[0], ok_s); failed++;
    end
    n = $sscanf("u v w z", "%s %s %s %s", c.sd[k], c.sq[$], c.in.iq[0], c.sa[k]);
    if (n != 4 || c.sd[1] != "u" || c.sq[0] != "v" || c.in.iq[0] != "w"
        || c.sa[1] != "z" || c.sa[0] != "m") begin
      $display("FAILED: string elements n=%0d %s %s %s %s %s", n, c.sd[1], c.sq[0],
               c.in.iq[0], c.sa[0], c.sa[1]); failed++;
    end
    // Reads of a missing element: 0 for int, "" for string.
    $sformat(text, "[%0d][%s][%b]", c.dq[k + 5], c.sd[7], c.in.bq[9]);
    if (text != "[0][][00000000]") begin
      $display("FAILED: missing-element reads %s", text); failed++;
    end
    // $cast takes the same writable element handle.
    if (!$cast(c.q[1], 8'd7) || c.q[1] != 7) begin
      $display("FAILED: $cast into q[1] gave %0d", c.q[1]); failed++;
    end
    $display("dq=%0d %0d %0d q=%0d %0d %0d bq=%h", c.dq[0], c.dq[1], c.dq[2],
             c.q[0], c.q[1], c.q[2], c.in.bq[0]);
    if (failed == 0) $display("PASSED");
  end
endmodule
