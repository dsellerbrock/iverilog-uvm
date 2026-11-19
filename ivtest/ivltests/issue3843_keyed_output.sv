module issue3843_keyed_output;
  typedef logic [63:0] wide_key_t;
  localparam wide_key_t LOW = 64'h0000_0000_0000_0003;
  localparam wide_key_t HIGH = 64'h8000_0000_0000_0003;
  typedef struct { int member; } struct_key_t;

  class key_t;
    int tag;
  endclass

  class maps_t;
    int entries[int];
    string labels[string];

    function int scan_entry();
      return $sscanf("31", "%d", entries[5]);
    endfunction
  endclass

  class holder_t;
    maps_t maps;
  endclass

  int wide[wide_key_t];
  int fresh[int];
  int untouched[int];
  real readings[string];
  int by_handle[key_t];
  int by_value[struct_key_t];
  int seeds[int] = '{default:23};
  wide_key_t bad_key = 64'h0000_00xz_0000_0003;
  holder_t holder;
  key_t first_key, second_key, alias_key;
  struct_key_t original_key, mutable_key;
  int seed, expected_random, actual_random;
  int failures;

  function int change_key();
    mutable_key.member = 2;
    return 8;
  endfunction

  task automatic check(bit ok, string what);
    if (!ok) begin
      $display("FAILED: %s", what);
      failures++;
    end
  endtask

  initial begin
    holder = new;
    holder.maps = new;
    first_key = new;
    second_key = new;
    first_key.tag = 7;
    second_key.tag = 7;
    alias_key = first_key;
    wide[LOW] = 11;
    wide[HIGH] = 12;

    check(wide.num() == 2 && wide.exists(LOW) && wide.exists(HIGH),
          "wide keys initially distinct");
    check(untouched.num() == 0 && !untouched.exists(8) && !untouched.exists(9),
          "module map initially empty");
    check(holder.maps.entries.num() == 0 && !holder.maps.entries.exists(5),
          "class map initially empty");
    check(readings.num() == 0 && !readings.exists("pressure")
          && holder.maps.labels.num() == 0 && !holder.maps.labels.exists("mode"),
          "string keys initially absent");
    check(by_handle.num() == 0 && !by_handle.exists(first_key)
          && !by_handle.exists(second_key), "object keys initially absent");

    check($value$plusargs("absent=%d", untouched[8]) == 0, "missing plusarg status");
    check($sscanf("bad", "%d", untouched[9]) == 0, "failed scan status");
    check($sscanf("27", "%*d", untouched[10]) == 0, "suppressed scan status");
    check($sscanf("bad", "%d", wide[LOW]) == 0 && wide[LOW] == 11,
          "failed scan preserves an existing entry");
    check(untouched.num() == 0 && !untouched.exists(8) && !untouched.exists(9)
          && !untouched.exists(10), "unsuccessful outputs leave the module map empty");

    check($value$plusargs("wide=%d", wide[HIGH]) == 1, "wide plusarg status");
    check(wide.num() == 2 && wide.exists(HIGH) && wide[HIGH] == -42
          && wide.exists(LOW) && wide[LOW] == 11, "overwrite only the full wide key");

    // First use of fresh, since a .num() query can initialize its backing map.
    check($sscanf("21 22 2.5 ready 41 42", "%d %d %f %s %d %d",
                  fresh[8], fresh[9], readings["pressure"], holder.maps.labels["mode"],
                  by_handle[first_key], by_handle[second_key]) == 6,
          "mixed native-key scan status");
    check(fresh.num() == 2 && fresh.exists(8) && fresh[8] == 21
          && fresh.exists(9) && fresh[9] == 22 && !fresh.exists(10),
          "two writes to a never-written module map");
    check(readings.num() == 1 && readings.exists("pressure")
          && readings["pressure"] == 2.5, "real value under a string key");
    check(holder.maps.labels.num() == 1 && holder.maps.labels.exists("mode")
          && holder.maps.labels["mode"] == "ready", "nested class map string output");
    check(by_handle.num() == 2 && by_handle.exists(alias_key)
          && by_handle[alias_key] == 41 && by_handle.exists(second_key)
          && by_handle[second_key] == 42, "class keys compare by handle identity");

    original_key = '{1};
    mutable_key = original_key;
    check($sscanf("53 21", "%d %d", by_value[mutable_key], fresh[change_key()]) == 2,
          "struct key scan status");
    check(by_value.num() == 1 && by_value.exists(original_key)
          && by_value[original_key] == 53 && !by_value.exists(mutable_key),
          "struct key captured before evaluating the later output");

    check(holder.maps.scan_entry() == 1, "direct class property scan status");
    check(holder.maps.entries.num() == 1 && holder.maps.entries.exists(5)
          && holder.maps.entries[5] == 31, "insert in a direct class property");

    check(seeds.num() == 0 && !seeds.exists(7), "default does not allocate an entry");
    seed = 23;
    expected_random = $random(seed);
    actual_random = $random(seeds[7]);
    check(actual_random == expected_random && seeds.num() == 1
          && seeds.exists(7) && seeds[7] == seed, "read the user default before writeback");

    check($sscanf("99", "%d", wide[bad_key]) == 1, "invalid-key scan conversion status");
    check(wide.num() == 2 && !wide.exists(bad_key) && wide[LOW] == 11
          && wide[HIGH] == -42, "invalid key leaves entries untouched");

    if (failures)
      $fatal(1, "%0d check(s) failed", failures);
    $display("PASSED");
  end
endmodule
