module sv_typeparam_enum_receiver_method;
  typedef enum int {
    SYNC_ACCEPTED,
    SYNC_UPDATED,
    SYNC_COMPLETED
  } sync_e;
  typedef enum logic [7:0] { WIDE_ZERO, WIDE_ONE } wide_e;
  typedef enum logic [1:0] { NARROW_ZERO, NARROW_ONE } narrow_e;

  class receiver_impl;
    int calls;

    function sync_e nb_transport_fw(input int transaction,
                                    ref int phase,
                                    input int delay);
      calls++;
      phase = transaction + delay;
      return SYNC_UPDATED;
    endfunction
  endclass

  class wide_receiver;
    function wide_e try_get();
      return WIDE_ONE;
    endfunction
  endclass

  class wide_forwarding_wrapper #(type IMP = int);
    IMP m_imp;
    function new(IMP imp); m_imp = imp; endfunction
    function wide_e forward(); return m_imp.try_get(); endfunction
  endclass

  class narrow_receiver;
    function narrow_e nb_transport_fw(input int value);
      return value ? NARROW_ONE : NARROW_ZERO;
    endfunction
  endclass

  class narrow_forwarding_wrapper #(type IMP = int);
    IMP m_imp;
    function new(IMP imp); m_imp = imp; endfunction
    function narrow_e forward(input int value);
      return m_imp.nb_transport_fw(value);
    endfunction
  endclass

  // The generic master intentionally has an unusable default receiver type.
  // Its call is deferred until a concrete specialization supplies IMP.
  class forwarding_wrapper #(type IMP = int);
    IMP m_imp;

    function new(IMP imp);
      m_imp = imp;
    endfunction

    function sync_e forward(input int transaction,
                            ref int phase,
                            input int delay);
      return m_imp.nb_transport_fw(transaction, phase, delay);
    endfunction
  endclass

  // A nested generic forwards its still-unresolved type parameter into the
  // inner wrapper. The inner specialization must remain deferred until the
  // outer wrapper receives a concrete receiver type.
  class nested_wrapper #(type IMP = int);
    forwarding_wrapper #(IMP) inner;

    function new(IMP imp);
      inner = new(imp);
    endfunction

    function sync_e forward(input int transaction,
                            ref int phase,
                            input int delay);
      return inner.forward(transaction, phase, delay);
    endfunction
  endclass

  // Preserve the symbolic receiver binding through another specialization
  // boundary.  A concrete deep_nested_wrapper specialization must eventually
  // dispatch the leaf call on receiver_impl, rather than merely suppressing it.
  class deep_nested_wrapper #(type IMP = int);
    nested_wrapper #(IMP) inner;

    function new(IMP imp);
      inner = new(imp);
    endfunction

    function sync_e forward(input int transaction,
                            ref int phase,
                            input int delay);
      return inner.forward(transaction, phase, delay);
    endfunction
  endclass

  initial begin
    receiver_impl impl;
    forwarding_wrapper #(receiver_impl) wrapper;
    nested_wrapper #(receiver_impl) nested;
    deep_nested_wrapper #(receiver_impl) deep_nested;
    wide_receiver wide_impl;
    wide_forwarding_wrapper #(wide_receiver) wide_wrapper;
    narrow_receiver narrow_impl;
    narrow_forwarding_wrapper #(narrow_receiver) narrow_wrapper;
    sync_e result;
    int phase;

    impl = new;
    wrapper = new(impl);
    result = wrapper.forward(3, phase, 4);

    if (result != SYNC_UPDATED || phase != 7 || impl.calls != 1) begin
      $display("FAILED result=%0d phase=%0d calls=%0d",
               result, phase, impl.calls);
      $finish(1);
    end

    nested = new(impl);
    result = nested.forward(5, phase, 6);
    if (result != SYNC_UPDATED || phase != 11 || impl.calls != 2) begin
      $display("FAILED nested result=%0d phase=%0d calls=%0d",
               result, phase, impl.calls);
      $finish(1);
    end

    deep_nested = new(impl);
    result = deep_nested.forward(7, phase, 8);
    if (result != SYNC_UPDATED || phase != 15 || impl.calls != 3) begin
      $display("FAILED deep nested result=%0d phase=%0d calls=%0d",
               result, phase, impl.calls);
      $finish(1);
    end

    wide_impl = new;
    wide_wrapper = new(wide_impl);
    if (wide_wrapper.forward() != WIDE_ONE) begin
      $display("FAILED widened deferred result");
      $finish(1);
    end

    narrow_impl = new;
    narrow_wrapper = new(narrow_impl);
    if (narrow_wrapper.forward(1) != NARROW_ONE) begin
      $display("FAILED truncated deferred result");
      $finish(1);
    end
    $display("PASSED");
  end
endmodule
