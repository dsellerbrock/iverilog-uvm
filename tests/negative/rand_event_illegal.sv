// IEEE 1800-2017 18.4: rand/randc is restricted to integral types.
// `event` is not integral. Unlike real/string/chandle, an `event` class
// property never reaches the normal property-recording path at all (the
// parser routes `event` declarations through pform_make_events(), not
// pform_class_property()), so the rand/randc qualifier must be rejected
// right at the class-item grammar rule or it silently vanishes with no
// diagnostic at all. Campaign 6 wave 2.
class C;
  rand event e;
endclass
module rand_event_illegal;
  initial begin
    C c = new();
  end
endmodule
