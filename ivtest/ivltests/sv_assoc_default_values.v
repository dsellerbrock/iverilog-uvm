// IEEE 1800-2017 7.9.11: an associative-array assignment pattern with a
// default key carries per-array fallback state without creating an entry.
class assoc_default_token;
  int value;

  function new(input int value);
    this.value = value;
  endfunction
endclass

class assoc_default_holder;
  int values[string];
  assoc_default_token object_values[int];
endclass

module main;
  typedef enum logic [2:0] { MODE_IDLE = 3'b001,
                            MODE_RUN  = 3'b101 } mode_t;

  logic [63:0] wide_values[int] =
        '{default:64'h1234_xz67_89ab_cdef};
  logic [63:0] wide_copy[int];
  real real_values[string] = '{default:3.25};
  string words[int] = '{default:"hello"};
  mode_t modes[string] = '{default:MODE_RUN};
  string vector_key_values[logic [47:0]] = '{default:"wide-key"};
  int wildcard_values[*] = '{default:201};
  int runtime_values[int];
  int eval_values[int];
  int scalar_replacement[int];
  int property_replacement[string];
  assoc_default_token object_values[int];
  assoc_default_token object_copy[int];
  assoc_default_token object_replacement[int];
  assoc_default_token side_effect_fallback;
  assoc_default_holder holder;

  bit failed;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  function automatic int replace_direct_scalar_during_rhs();
    eval_values = scalar_replacement;
    return 142;
  endfunction

  function automatic int replace_property_scalar_during_rhs();
    holder.values = property_replacement;
    return 177;
  endfunction

  function automatic assoc_default_token replace_direct_object_during_rhs();
    object_values = object_replacement;
    return side_effect_fallback;
  endfunction

  function automatic assoc_default_token replace_property_object_during_rhs();
    holder.object_values = object_replacement;
    return side_effect_fallback;
  endfunction

  initial begin
    int key;
    int seed;
    assoc_default_token fallback;
    assoc_default_token explicit_value;

    failed = 1'b0;

    // A missing read returns the exact full-width 4-state default but does
    // not create a key for exists(), size(), or ordered traversal.
    check("wide absent default",
          wide_values[-19] === 64'h1234_xz67_89ab_cdef);
    check("wide absent is not an entry", !wide_values.exists(-19));
    check("wide absent size", wide_values.size() == 0);
    key = 0;
    check("wide absent traversal", wide_values.first(key) == 0);
    wide_values.delete(-19);
    check("wide delete missing does not insert", wide_values.size() == 0);

    // An explicit entry shadows the fallback. Removing it reveals the same
    // fallback again without leaving a phantom entry.
    wide_values[-19] = 64'hfeed_face_0123_4567;
    check("wide explicit wins",
          wide_values[-19] === 64'hfeed_face_0123_4567);
    check("wide other key keeps default",
          wide_values[77] === 64'h1234_xz67_89ab_cdef);
    check("wide explicit membership",
          wide_values.exists(-19) && wide_values.size() == 1);
    wide_values.delete(-19);
    check("wide delete reveals default",
          wide_values[-19] === 64'h1234_xz67_89ab_cdef);
    check("wide delete removes membership",
          !wide_values.exists(-19) && wide_values.size() == 0);

    // Whole-array copies snapshot both explicit entries and fallback state.
    wide_values[4] = 64'h0000_0000_0000_4444;
    wide_copy = wide_values;
    check("copy carries default",
          wide_copy[99] === 64'h1234_xz67_89ab_cdef);
    check("copy carries explicit entry",
          wide_copy.exists(4) &&
          wide_copy[4] === 64'h0000_0000_0000_4444);
    wide_values[4] = 64'h0000_0000_0000_5555;
    check("copy has independent entries",
          wide_copy[4] === 64'h0000_0000_0000_4444);

    // Replacing the whole array with another default pattern clears prior
    // explicit keys and installs the new fallback atomically.
    wide_values = '{default:64'hzzzz_0000_xxxx_1111};
    check("reassignment clears explicit entries",
          wide_values.size() == 0 && !wide_values.exists(4));
    check("reassignment installs new default",
          wide_values[4] === 64'hzzzz_0000_xxxx_1111);
    check("copy retains old default",
          wide_copy[99] === 64'h1234_xz67_89ab_cdef);
    wide_values[8] = 64'h8;
    wide_values.delete();
    check("delete all keeps fallback",
          wide_values.size() == 0 &&
          wide_values[8] === 64'hzzzz_0000_xxxx_1111);

    // String and vector key maps use the same per-container fallback state.
    check("real string-key default", real_values["missing"] == 3.25);
    check("real read does not insert", real_values.size() == 0);
    real_values["live"] = -1.5;
    check("real explicit wins", real_values["live"] == -1.5);
    real_values.delete();
    check("real delete all keeps default",
          real_values.size() == 0 && real_values["live"] == 3.25);

    check("string default", words[7] == "hello");
    words[7] = "world";
    check("string explicit wins", words[7] == "world");
    check("string missing remains default", words[8] == "hello");

    check("enum default", modes["missing"] == MODE_RUN);
    check("enum default does not insert", modes.size() == 0);
    modes["live"] = MODE_IDLE;
    check("enum explicit wins", modes["live"] == MODE_IDLE);

    check("wide vector key default",
          vector_key_values[48'h1234_5678_9abc] == "wide-key");
    check("wide vector key read does not insert",
          vector_key_values.size() == 0);
    vector_key_values[48'hffff_0000_2222] = "explicit";
    check("wide vector key explicit wins",
          vector_key_values[48'hffff_0000_2222] == "explicit");

    // A wildcard-index map must retain full runtime key width while the
    // fallback remains independent of membership. This covers both sides of
    // the parser's placeholder index width.
    check("wildcard narrow-key default", wildcard_values[8'h12] == 201);
    check("wildcard wide-key default",
          wildcard_values[48'h1234_5678_9abc] == 201);
    check("wildcard reads do not insert", wildcard_values.size() == 0);
    wildcard_values[8'h12] = 202;
    check("wildcard explicit narrow key", wildcard_values[8'h12] == 202);
    check("wildcard wide key keeps default",
          wildcard_values[48'h1234_5678_9abc] == 201);

    // Procedural defaults capture the value at the whole assignment.
    seed = 40;
    runtime_values = '{default:seed + 2};
    seed = 99;
    check("runtime default evaluated at assignment", runtime_values[5] == 42);
    check("runtime default has no entry", runtime_values.size() == 0);
    runtime_values[5] += 3;
    check("compound update starts from fallback",
          runtime_values.exists(5) && runtime_values[5] == 45);
    check("compound update leaves other fallback",
          !runtime_values.exists(6) && runtime_values[6] == 42);

    // RHS evaluation precedes replacement of the destination. Each helper
    // deliberately replaces the same array; the outer default assignment must
    // then supersede that side effect rather than mutate a captured old handle.
    eval_values[1] = 1;
    eval_values = '{};
    check("empty pattern remains legal",
          eval_values.size() == 0 && !eval_values.exists(1));
    scalar_replacement[9] = 900;
    eval_values = '{default:replace_direct_scalar_during_rhs()};
    check("direct scalar RHS replacement superseded",
          eval_values.size() == 0 && !eval_values.exists(9) &&
          eval_values[9] == 142);

    // A class-handle default has reference semantics. Copies carry the same
    // fallback handle, while explicit entries still shadow it.
    fallback = new(17);
    explicit_value = new(31);
    object_values = '{default:fallback};
    check("class default handle", object_values[100] == fallback);
    check("class default does not insert", object_values.size() == 0);
    object_values[3] = explicit_value;
    check("class explicit wins", object_values[3] == explicit_value);
    object_copy = object_values;
    check("class copy carries default", object_copy[101] == fallback);
    check("class copy carries explicit", object_copy[3] == explicit_value);
    fallback.value = 23;
    check("class fallback keeps reference semantics",
          object_values[200].value == 23 && object_copy[200].value == 23);
    object_values.delete();
    check("class delete all keeps fallback",
          object_values.size() == 0 && object_values[3] == fallback);

    side_effect_fallback = new(57);
    object_replacement[9] = explicit_value;
    object_values = '{default:replace_direct_object_during_rhs()};
    check("direct class RHS replacement superseded",
          object_values.size() == 0 && !object_values.exists(9) &&
          object_values[9] == side_effect_fallback);

    // Class-property associative arrays consume the same whole-pattern form.
    holder = new;
    holder.values["old"] = 1;
    holder.values = '{default:77};
    check("property reassignment clears entries",
          holder.values.size() == 0 && !holder.values.exists("old"));
    check("property default", holder.values["missing"] == 77);
    holder.values["live"] = 88;
    check("property explicit wins", holder.values["live"] == 88);
    holder.values.delete();
    check("property delete all keeps default",
          holder.values.size() == 0 && holder.values["live"] == 77);

    property_replacement["rhs"] = 900;
    holder.values = '{default:replace_property_scalar_during_rhs()};
    check("property scalar RHS replacement superseded",
          holder.values.size() == 0 && !holder.values.exists("rhs") &&
          holder.values["rhs"] == 177);

    // A class-handle property exercises the object-stack form: the receiver,
    // associative container, and default handle must remain distinct.
    holder.object_values = '{default:fallback};
    check("property class default handle",
          holder.object_values[50] == fallback &&
          holder.object_values.size() == 0);
    holder.object_values[1] = explicit_value;
    check("property class explicit wins",
          holder.object_values[1] == explicit_value);
    holder.object_values.delete();
    check("property class delete keeps fallback",
          holder.object_values.size() == 0 &&
          holder.object_values[1] == fallback);

    holder.object_values =
          '{default:replace_property_object_during_rhs()};
    check("property class RHS replacement superseded",
          holder.object_values.size() == 0 &&
          !holder.object_values.exists(9) &&
          holder.object_values[9] == side_effect_fallback);

    if (failed)
      $display("FAILED");
    else
      $display("PASSED");
  end
endmodule
