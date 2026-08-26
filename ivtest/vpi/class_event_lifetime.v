// IEEE 1800-2017 8.9 and IEEE 1800 VPI 37.36: a static class event is
// shared class storage and must report vpiAutomatic == 0 even when it is
// referenced from an automatic class method.
module class_event_lifetime;
  class event_box;
    static event shared_ev;

    task check_lifetime;
      $check_static_class_event(shared_ev);
    endtask
  endclass

  event_box box;

  initial begin
    box = new;
    box.check_lifetime();
  end
endmodule
