// Associative-array casts and assignment-like contexts require an associative
// value with the exact same element type, key type, and wildcard state. The
// implementation's shared netqueue_t carrier must not erase those distinctions.
module sv_assoc_default_cast_fail;
  typedef int int_by_string_t[string];
  typedef string string_by_string_t[string];
  typedef int int_by_int_t[int];
  typedef int int_queue_t[$];
  typedef int int_darray_t[];
  typedef int int_fixed_t[2];

  int_by_string_t value;
  int_queue_t queue_value;
  int_darray_t darray_value;
  int_fixed_t fixed_value;
  bit choose;
  bit sink;

  function automatic bit accepts(input int_by_string_t argument);
    return argument.size() == 0;
  endfunction

  initial begin
    value = int_by_string_t'(32'h1234);
    value = int_by_string_t'(
        string_by_string_t'{default:"bad"});
    value = int_by_string_t'(
        int_by_int_t'{default:7});

    value = string_by_string_t'{default:"bad direct"};
    value = int_by_int_t'{default:8};

    sink = accepts(string_by_string_t'{default:"bad formal"});
    sink = accepts(int_by_int_t'{default:9});

    // Check both arms: the first has the required type, while the second
    // must not be hidden by the conditional expression's QUEUE category.
    value = choose ? int_by_string_t'{default:10}
                   : string_by_string_t'{default:"bad ternary"};
    value = choose ? int_by_string_t'{default:11}
                   : int_by_int_t'{default:12};

    // Check the reverse boundary as well: ordinary containers cannot be
    // stored in an associative array merely because they share an internal
    // queue/dynamic-array carrier.
    value = queue_value;
    value = darray_value;
    value = fixed_value;
  end
endmodule
