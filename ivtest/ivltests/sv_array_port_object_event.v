class array_port_event_object;
  integer tag;

  function new(integer value);
    tag = value;
  endfunction
endclass

module sv_array_port_object_event;
  array_port_event_object objects [0:1];
  array_port_event_object sibling_a;
  array_port_event_object sibling_b;
  array_port_event_object selected_a;
  array_port_event_object selected_b;
  integer selected_wakes = 0;

  // A constant fixed-array element is lowered to a VVP .array/port. Object
  // handle changes must use the object channel, while the sibling word stays
  // outside this event's sensitivity.
  always @(objects[1])
    selected_wakes = selected_wakes + 1;

  initial begin
    sibling_a = new(10);
    sibling_b = new(20);
    selected_a = new(11);
    selected_b = new(22);

    // Ensure the waiter is armed after the pre-simulation nil-object seed.
    #1;
    objects[0] = sibling_a;
    #1;
    if (selected_wakes != 0)
      $fatal(1, "sibling object word woke event: %0d", selected_wakes);

    objects[1] = selected_a;
    #1;
    if (selected_wakes != 1)
      $fatal(1, "selected object handle did not wake once: %0d", selected_wakes);

    objects[0] = sibling_b;
    #1;
    if (selected_wakes != 1)
      $fatal(1, "second sibling object write woke event: %0d", selected_wakes);

    objects[1] = selected_b;
    #1;
    if (selected_wakes != 2)
      $fatal(1, "second selected object handle did not wake: %0d", selected_wakes);
    if (objects[1].tag != 22)
      $fatal(1, "selected object payload mismatch: %0d", objects[1].tag);

    $display("PASSED object-array wakes=%0d tag=%0d",
             selected_wakes, objects[1].tag);
  end
endmodule
