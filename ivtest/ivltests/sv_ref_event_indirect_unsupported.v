`timescale 1ns/1ps

class ref_event_property_c;
  logic ready;
endclass

// IEEE 1800-2023 13.5.2: a class property may be passed by reference and
// an event control on the formal sees the caller's change (#2993).
module sv_ref_event_property;
  ref_event_property_c item;

  task automatic await_ready(const ref logic ready);
    @(posedge ready);
  endtask

  initial begin
    item = new;
    fork begin await_ready(item.ready); $display("PASSED"); $finish; end join_none
    #1 item.ready = 1;
    #1 $fatal(1, "event-sensitive property ref silently stalled");
  end
endmodule

module sv_ref_event_element_unsupported;
  logic values[];

  task automatic await_ready(const ref logic ready);
    @(posedge ready);
  endtask

  initial begin
    values = new[1];
    fork await_ready(values[0]); join_none
    #1 values[0] = 1;
    #1 $fatal(1, "event-sensitive dynamic element ref silently stalled");
  end
endmodule

module sv_ref_event_word_unsupported;
  logic values[1];

  task automatic await_ready(const ref logic ready);
    @(posedge ready);
  endtask

  initial begin
    fork await_ready(values[0]); join_none
    #1 values[0] = 1;
    #1 $fatal(1, "event-sensitive fixed word ref silently stalled");
  end
endmodule
