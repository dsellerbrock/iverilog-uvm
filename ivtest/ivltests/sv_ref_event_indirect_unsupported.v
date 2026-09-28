`timescale 1ns/1ps

class ref_event_property_c;
  logic ready;
endclass

module sv_ref_event_property_unsupported;
  ref_event_property_c item;

  task automatic await_ready(const ref logic ready);
    @(posedge ready);
  endtask

  initial begin
    item = new;
    fork await_ready(item.ready); join_none
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
