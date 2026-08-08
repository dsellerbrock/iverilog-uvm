// A void cast may discard a non-void method result. Width/type analysis must
// follow an unpacked-struct member to the class receiver instead of inventing
// an object result for a bit-returning method.
class void_struct_worker_base;
  int calls;

  function bit plain_touch(int delta);
    calls += delta;
    return 1'b1;
  endfunction

  virtual function bit touch(int delta);
    calls += delta;
    return 1'b1;
  endfunction

  function void_struct_worker_base identity(int delta);
    calls += delta;
    return this;
  endfunction
endclass

class void_struct_worker_derived extends void_struct_worker_base;
  function bit touch(int delta);
    calls += 2 * delta;
    return 1'b1;
  endfunction
endclass

typedef struct {
  void_struct_worker_base direct;
  void_struct_worker_base polymorphic;
  int guard;
} void_struct_holder_t;

module sv_void_cast_struct_method;
  task automatic exercise;
    void_struct_holder_t holder;
    void_struct_worker_derived derived;
    int errors;

    errors = 0;
    holder.direct = new;
    derived = new;
    holder.polymorphic = derived;
    holder.guard = 32'h1357_9bdf;

    // Both calls return bit and are intentionally discarded. They cover the
    // nonvirtual and virtual call forms from the OpenTitan witness; the second
    // also proves dispatch through the separately selected member.
    void'(holder.direct.plain_touch(.delta(3)));
    void'(holder.polymorphic.touch(.delta(5)));

    // Keep an object-returning sibling as a result-type guard.
    void'(holder.direct.identity(.delta(4)));

    if (holder.direct.calls !== 7) begin
      $display("F1 direct calls=%0d", holder.direct.calls);
      errors++;
    end
    if (holder.polymorphic.calls !== 10) begin
      $display("F2 polymorphic calls=%0d", holder.polymorphic.calls);
      errors++;
    end
    if (holder.guard !== 32'h1357_9bdf) begin
      $display("F3 guard=%h", holder.guard);
      errors++;
    end

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED %0d", errors);
  endtask

  initial exercise();
endmodule
