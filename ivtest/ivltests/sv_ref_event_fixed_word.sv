`timescale 1ns/1ns

module sv_ref_event_fixed_word;
  int arr[0:2];
  int words[7:5];
  integer four_state[0:2];
  bit [3:0] bits[1:2];
  real reals[0:1];
  string strings[0:1];

  class item;
    int id;
    function new(int id);
      this.id = id;
    endfunction
  endclass
  item handles[0:1];

  int index = 5, index_calls = 0;
  bit direct_seen;
  bit [4:0] seen;
  bit real_seen, string_seen, object_seen;
  logic [79:0] wide;

  task automatic w(ref int r);
    @(r);
    if ($time != 3 || r !== 5)
      $fatal(1, "direct ref woke at %0t with %0d", $time, r);
    $display("J %0t %0d", $time, r);
    direct_seen = 1;
  endtask

  function automatic int select_word();
    index_calls++;
    return index;
  endfunction

  task automatic observe(ref int r, input int tag, when_expected, value_expected);
    @(r);
    if ($time != when_expected || r !== value_expected)
      $fatal(1, "word ref %0d woke at %0t with %0d", tag, $time, r);
    seen[tag] = 1;
  endtask

  task automatic forward_word(ref int r);
    #2 observe(r, 0, 9, 42);
  endtask

  task automatic update_word(ref int r, input int value);
    r = value;
  endtask

  task automatic observe_rise(const ref logic r);
    @(posedge r);
    if ($time != 20 || r !== 1'b1)
      $fatal(1, "static local word ref woke at %0t with %b", $time, r);
    seen[4] = 1;
  endtask

  task automatic observe_static_local;
    static logic local_words[1];
    local_words[0] = 1'b1;
    fork
      observe_rise(local_words[0]);
      begin
        #1 local_words[0] = 1'b0;
        #1 local_words[0] = 1'b1;
      end
    join
  endtask

  task automatic observe_real(ref real r);
    @(r);
    if ($time != 17 || r != 2.5)
      $fatal(1, "real word ref woke at %0t with %f", $time, r);
    real_seen = 1;
  endtask

  task automatic observe_string(ref string r);
    @(r);
    if ($time != 17 || r != "new")
      $fatal(1, "string word ref woke at %0t with %s", $time, r);
    string_seen = 1;
  endtask

  task automatic observe_object(ref item r);
    @(r);
    if ($time != 17 || r == null || r.id != 2)
      $fatal(1, "object word ref woke with wrong time or handle at %0t", $time);
    object_seen = 1;
  endtask

  task automatic invalid_integer(ref integer r);
    if (r !== 'x) $fatal(1, "invalid four-state word did not read as X");
    r = 99;
    if (r !== 'x) $fatal(1, "write through an invalid four-state word changed it");
  endtask

  task automatic invalid_wait(ref integer r);
    invalid_integer(r);
    @(r);
    $fatal(1, "invalid word received an event");
  endtask

  task automatic invalid_bit(ref bit [3:0] r);
    if (r !== 0) $fatal(1, "invalid two-state word did not read as zero");
    r = 9;
    if (r !== 0) $fatal(1, "write through an invalid two-state word changed it");
  endtask

  initial begin
    arr[1] = 4;
    fork w(arr[1]); join_none
    #1 arr[0] = 7;
    #1 arr[2] = 9;
    #1 arr[1] = 5;
    #1 if (!direct_seen) $fatal(1, "direct fixed-word ref missed its event");

    words[5] = 11;
    words[6] = 22;
    fork
      forward_word(words[select_word()]);
      observe(words[5], 1, 9, 42);
    join_none
    #1 index = 6;
    #2 words[6] = 30;
    #1 words[5] = 11;
    #1 update_word(words[5], 42);
    #1 if (seen !== 5'b00011 || words[5] !== 42 || index_calls != 1)
      $fatal(1, "fixed-word ref missed the aliased write or recaptured its index");

    fork observe(words[5], 2, 0, 0); join_none
    #1 disable fork;
    fork observe(words[6], 3, 13, 66); join_none
    #1 words[5] = 55;
    #1 words[6] = 66;
    #1 if (seen !== 5'b01011) $fatal(1, "fixed-word ref failed cancellation or re-entry");

    reals[1] = 1.25;
    strings[1] = "initial";
    handles[1] = new(1);
    fork
      observe_real(reals[1]);
      observe_string(strings[1]);
      observe_object(handles[1]);
    join_none
    #1;
    reals[0] = 2.5;
    strings[0] = "other";
    handles[0] = new(2);
    #1;
    reals[1] = 1.25;
    strings[1] = "initial";
    handles[1] = handles[1];
    #1;
    reals[1] = 2.5;
    strings[1] = "new";
    handles[1] = handles[0];
    #1 if (!real_seen || !string_seen || !object_seen)
      $fatal(1, "typed fixed-word ref missed an event");

    fork observe_static_local; join_none
    four_state[1] = 5;
    // The low bits alone would select a valid word in each case.
    wide = 80'h1_0000_0001;
    invalid_integer(four_state[wide]);
    wide[75] = 1'bx;
    invalid_integer(four_state[wide]);
    wide = 80'h1_0000_0000_0000_0001;
    fork invalid_wait(four_state[wide]); join_none
    bits[1] = 4;
    index = 3;
    invalid_bit(bits[index]);
    index = -1;
    invalid_integer(four_state[index]);
    #1 if (four_state[1] !== 5 || bits[1] !== 4)
      $fatal(1, "invalid word was narrowed onto a valid word");
    four_state[1] = 8;
    #2 if (!seen[4]) $fatal(1, "static local word ref missed its event");
    disable fork;
    $display("PASSED");
    $finish(0);
  end

  initial #25 $fatal(1, "fixed-word ref test timed out");
endmodule
