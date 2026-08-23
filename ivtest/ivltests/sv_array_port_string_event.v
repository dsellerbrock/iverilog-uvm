module sv_array_port_string_event;
  string words [0:1];
  integer selected_wakes = 0;

  // A constant fixed-array element is lowered to a VVP .array/port. The
  // port must be seeded and updated through the string channel, and changes
  // to the sibling word must not wake this process.
  always @(words[1])
    selected_wakes = selected_wakes + 1;

  initial begin
    // Let the pre-simulation empty-string seed establish the event baseline.
    #1;
    words[1] = "";
    #1;
    if (selected_wakes != 0)
      $fatal(1, "empty string unexpectedly woke event: %0d", selected_wakes);

    words[0] = "sibling-a";
    #1;
    if (selected_wakes != 0)
      $fatal(1, "sibling string word woke event: %0d", selected_wakes);

    words[1] = "selected-a";
    #1;
    if (selected_wakes != 1)
      $fatal(1, "selected string word did not wake once: %0d", selected_wakes);

    words[0] = "sibling-b";
    #1;
    if (selected_wakes != 1)
      $fatal(1, "second sibling string write woke event: %0d", selected_wakes);

    words[1] = "selected-b";
    #1;
    if (selected_wakes != 2)
      $fatal(1, "second selected string write did not wake: %0d", selected_wakes);

    $display("PASSED string-array wakes=%0d value=%s",
             selected_wakes, words[1]);
  end
endmodule
