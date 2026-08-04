// A parameterized class body is a template. Calls through a type-parameter
// property must be resolved in the concrete specialization, not rejected
// while the generic master is elaborated with IMP's intentionally unusable
// default type. The concrete calls must remain real calls, not placeholders.
module sv_typeparam_receiver_method;

  class receiver_impl;
    int calls;

    function bit try_put(int value);
      calls++;
      return value == 37;
    endfunction

    function bit can_put();
      calls++;
      return 1'b1;
    endfunction

    function receiver_impl get_comp();
      calls++;
      return this;
    endfunction
  endclass

  // UVM's multi-socket forwarding classes use an alias chain before the
  // receiver property reaches the enclosing type parameter.
  class alias_proxy #(type IMP = int, type REQ_IMP = IMP);
    typedef REQ_IMP this_req_type;
    local this_req_type m_req_imp;

    function new(this_req_type imp);
      m_req_imp = imp;
    endfunction

    function bit forward(int value);
      return m_req_imp.try_put(value) && m_req_imp.can_put();
    endfunction
  endclass

  // uvm_port_base::get_comp builds a method-local associative array whose
  // element type is a class type parameter, then calls through an element.
  class local_assoc_proxy #(type PORT = int);
    local PORT m_port;

    function new(PORT port);
      m_port = port;
    endfunction

    function receiver_impl forward();
      PORT list1[string];
      list1["item"] = m_port;
      return list1["item"].get_comp();
    endfunction
  endclass

  class generic_proxy #(type IMP = int);
    local IMP m_imp;

    function new(IMP imp);
      m_imp = imp;
    endfunction

    function bit forward(int value);
      return m_imp.try_put(value) && m_imp.can_put();
    endfunction
  endclass

  initial begin
    receiver_impl impl;
    receiver_impl alias_impl;
    receiver_impl assoc_impl;
    receiver_impl got;
    generic_proxy #(receiver_impl) proxy;
    alias_proxy #(receiver_impl) alias_forwarder;
    local_assoc_proxy #(receiver_impl) assoc_forwarder;

    impl = new;
    alias_impl = new;
    assoc_impl = new;
    proxy = new(impl);
    alias_forwarder = new(alias_impl);
    assoc_forwarder = new(assoc_impl);

    if (!proxy.forward(37)) begin
      $display("FAILED: concrete forwarding returned false");
      $finish(1);
    end
    if (impl.calls != 2) begin
      $display("FAILED: concrete receiver calls=%0d, expected 2", impl.calls);
      $finish(1);
    end

    if (!alias_forwarder.forward(37)) begin
      $display("FAILED: aliased forwarding returned false");
      $finish(1);
    end
    if (alias_impl.calls != 2) begin
      $display("FAILED: aliased receiver calls=%0d, expected 2",
               alias_impl.calls);
      $finish(1);
    end

    got = assoc_forwarder.forward();
    if (got != assoc_impl) begin
      $display("FAILED: local associative receiver returned wrong object");
      $finish(1);
    end
    if (assoc_impl.calls != 1) begin
      $display("FAILED: local associative receiver calls=%0d, expected 1",
               assoc_impl.calls);
      $finish(1);
    end

    $display("PASSED");
    $finish(0);
  end

endmodule
