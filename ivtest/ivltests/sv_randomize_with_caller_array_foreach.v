// An inline randomize() constraint may index a caller array with the iterator
// of a constraint foreach: foreach (data[i]) data[i] == local::src[i].
// IEEE 1800-2017 18.7.1: local:: names the caller's scope, but the iterator
// belongs to the constraint, so it was left unbound in the caller scope and
// the element silently read as zero. Covers a dynamic array, a queue, a fixed
// array, a plain (unqualified) caller array, a computed index, the
// std::randomize() with form, and an out-of-range caller index.
class item4;
  rand logic [7:0] dyn[];
endclass

class item;
  rand bit [7:0] dyn[];
  rand bit [7:0] q[$];
  rand bit [7:0] fixed[4];
endclass

class seq;
  item req;
  bit [7:0] src[];
  bit [7:0] srcq[$];
  bit [7:0] srcf[4];
  logic [7:0] src4[] = '{8'h11, 8'h22, 8'h33};
  item4 req4;

  task copy_local();
    req = new;
    void'(req.randomize() with {
      dyn.size() == local::src.size();
      foreach (dyn[i]) dyn[i] == local::src[i];
    });
  endtask
  task copy_plain();
    req = new;
    void'(req.randomize() with {
      dyn.size() == src.size();
      foreach (dyn[i]) dyn[i] == src[i];
    });
  endtask
  task copy_reversed();
    req = new;
    void'(req.randomize() with {
      dyn.size() == local::src.size();
      foreach (dyn[i]) dyn[i] == local::src[local::src.size() - 1 - i];
    });
  endtask
  task copy_queue();
    req = new;
    void'(req.randomize() with {
      q.size() == local::srcq.size();
      foreach (q[i]) q[i] == local::srcq[i];
    });
  endtask
  task copy_fixed();
    req = new;
    void'(req.randomize() with {
      foreach (fixed[i]) fixed[i] == local::srcf[i];
    });
  endtask
  function bit copy_too_long4();
    req4 = new;
    return req4.randomize() with {
      dyn.size() == local::src4.size() + 2;
      foreach (dyn[i]) dyn[i] == local::src4[i];
    };
  endfunction
  function bit copy_too_long();
    req = new;
    return req.randomize() with {
      dyn.size() == local::src.size() + 2;
      foreach (dyn[i]) dyn[i] == local::src[i];
    };
  endfunction
endclass

module main;
  int errors;

  initial begin
    automatic seq s = new;
    automatic bit [7:0] dst[$];
    automatic bit [7:0] loc[];
    automatic bit [7:0] one;

    s.src  = '{8'h11, 8'h22, 8'h33};
    s.srcq = '{8'h44, 8'h55};
    s.srcf = '{8'h66, 8'h77, 8'h88, 8'h99};

    repeat (4) begin
      s.copy_local();
      if (s.req.dyn.size() != 3) begin $display("FAILED local size %0d", s.req.dyn.size()); errors++; end
      else foreach (s.src[i]) if (s.req.dyn[i] !== s.src[i]) begin
        $display("FAILED local dyn[%0d]=%h want %h", i, s.req.dyn[i], s.src[i]); errors++;
      end

      s.copy_plain();
      foreach (s.src[i]) if (s.req.dyn[i] !== s.src[i]) begin
        $display("FAILED plain dyn[%0d]=%h want %h", i, s.req.dyn[i], s.src[i]); errors++;
      end

      s.copy_reversed();
      foreach (s.src[i]) if (s.req.dyn[i] !== s.src[2 - i]) begin
        $display("FAILED reversed dyn[%0d]=%h want %h", i, s.req.dyn[i], s.src[2 - i]); errors++;
      end

      s.copy_queue();
      foreach (s.srcq[i]) if (s.req.q[i] !== s.srcq[i]) begin
        $display("FAILED queue q[%0d]=%h want %h", i, s.req.q[i], s.srcq[i]); errors++;
      end

      s.copy_fixed();
      foreach (s.srcf[i]) if (s.req.fixed[i] !== s.srcf[i]) begin
        $display("FAILED fixed[%0d]=%h want %h", i, s.req.fixed[i], s.srcf[i]); errors++;
      end
    end

    // Past the end of a 2-state caller array an element reads as 0
    // (Table 7-1), so the two extra elements are constrained to 0.
    if (!s.copy_too_long()) begin $display("FAILED 2-state out-of-range read"); errors++; end
    else begin
      if (s.req.dyn.size() != 5 || s.req.dyn[3] !== 8'h00 || s.req.dyn[4] !== 8'h00) begin
        $display("FAILED 2-state out-of-range elements %p", s.req.dyn); errors++;
      end
    end
    // Past the end of a 4-state caller array the element is X: an 18.3 error,
    // so randomize() fails rather than choosing a value.
    if (s.copy_too_long4()) begin $display("FAILED 4-state out-of-range read solved"); errors++; end

    // std::randomize() with a foreach over its own queue.
    loc = '{8'hA1, 8'hB2, 8'hC3, 8'hD4};
    void'(std::randomize(dst) with { dst.size() == loc.size(); foreach (dst[i]) dst[i] == loc[i]; });
    if (dst.size() != 4) begin $display("FAILED scope size %0d", dst.size()); errors++; end
    else foreach (loc[i]) if (dst[i] !== loc[i]) begin
      $display("FAILED scope dst[%0d]=%h want %h", i, dst[i], loc[i]); errors++;
    end

    // A constant index into a caller dynamic array is an element, not a bit.
    void'(std::randomize(one) with { one == loc[2]; });
    if (one !== 8'hC3) begin $display("FAILED scope constant index one=%h", one); errors++; end

    if (errors == 0) $display("PASSED");
  end
endmodule
