package class_static_get_reentry_pkg;
  class base_object;
  endclass

  class report_object extends base_object;
  endclass

  class event_object extends base_object;
  endclass

  class callback;
  endclass

  class event_callback extends callback;
  endclass

  class typed_callbacks #(type T = base_object);
  endclass

  class callbacks #(type T = base_object, type CB = callback)
      extends typed_callbacks#(T);
    typedef callbacks#(T, CB) this_type;

    local static this_type m_inst;
    static callbacks#(T, callback) m_base_inst;
    local static int m_marker;

    static function this_type get();
      if (m_inst == null) begin
        m_inst = new;

        // The base specialization is the current specialization when
        // CB=callback. m_inst is installed before the recursive call, so the
        // call is live and observable but terminates on its second entry.
        if (m_base_inst == null)
          m_base_inst = callbacks#(T, callback)::get();
      end
      return m_inst;
    endfunction

    static function bit base_linked();
      return m_base_inst != null;
    endfunction

    static function void set_marker(int value);
      m_marker = value;
    endfunction

    static function int marker();
      return m_marker;
    endfunction

    static function void add();
      void'(get());

      // Create a second concrete specialization from inside an already
      // specialized method, matching the UVM callback registration shape.
      void'(callbacks#(report_object, callback)::get());
    endfunction
  endclass
endpackage

module sv_class_static_get_specialization_reentry;
  import class_static_get_reentry_pkg::*;

  callbacks#(event_object, event_callback) event_inst_0;
  callbacks#(event_object, event_callback) event_inst_1;
  callbacks#(report_object, callback) report_inst;

  initial begin
    callbacks#(event_object, event_callback)::add();
    event_inst_0 = callbacks#(event_object, event_callback)::get();
    event_inst_1 = callbacks#(event_object, event_callback)::get();
    report_inst = callbacks#(report_object, callback)::get();

    callbacks#(event_object, event_callback)::set_marker(11);
    callbacks#(report_object, callback)::set_marker(22);

    if (event_inst_0 == null || event_inst_0 != event_inst_1 ||
        report_inst == null ||
        !callbacks#(event_object, event_callback)::base_linked() ||
        !callbacks#(report_object, callback)::base_linked() ||
        callbacks#(event_object, event_callback)::marker() != 11 ||
        callbacks#(report_object, callback)::marker() != 22) begin
      $display("FAILED");
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
