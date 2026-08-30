// A single event-expression leaf that mixes virtual-interface and
// class-property dependencies still needs a synchronous value recipe. An
// explicit event-or list is covered by sv_class_property_mixed_event_value_change.
interface mixed_event_if;
  logic signal;
endinterface

class mixed_event_state;
  virtual mixed_event_if vif;
  bit watched;
endclass

module sv_class_property_mixed_event_reject;
  mixed_event_if vif();
  mixed_event_state state;

  initial begin
    state = new;
    state.vif = vif;
    @(state.vif.signal || state.watched);
  end
endmodule
