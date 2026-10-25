// IEEE 1800-2017 §18.5.4 and IEEE 1800-2023 §18.5.3 require a rand variable
// in each dist expression.
class dist_state_only;
  typedef struct { bit [3:0] field; } plain_t;
  typedef struct { rand bit [3:0] field; } qualified_t;

  bit [7:0] state;
  rand bit [7:0] r;
  rand bit [7:0] rand_argument;
  bit choose_state;
  plain_t plain_value;
  rand plain_t rand_plain_value;
  qualified_t nonrand_qualified_value;
  int unsigned state_assoc[string];
  int unsigned state_dynamic[];
  int unsigned state_fixed[4];

  function bit [7:0] read_r();
    return r;
  endfunction
  function bit [7:0] identity(input bit [7:0] value);
    return value;
  endfunction

  constraint state_subject { state dist {0, 1}; }
  constraint method_subject { read_r() dist {0, 1}; }
  constraint function_argument_subject { identity(rand_argument) dist {0, 1}; }
  constraint countones_state_subject { $countones(state) dist {1 := 1}; }
  constraint constant_subject { 8'd0 dist {0, 1}; }
  constraint soft_state_subject { soft state dist {0, 1}; }
  constraint implication_state_subject {
    choose_state -> state dist {0, 1};
  }
  constraint plain_struct_member_subject {
    plain_value.field dist {5 := 1};
  }
  constraint rand_struct_unqualified_member_subject {
    rand_plain_value.field dist {5 := 1};
  }
  constraint nonrand_struct_qualified_member_subject {
    nonrand_qualified_value.field dist {5 := 1};
  }
  constraint state_assoc_array_subject {
    foreach (state_assoc[i]) state_assoc[i] dist {0, 1};
  }
  constraint state_dynamic_array_subject {
    foreach (state_dynamic[i]) state_dynamic[i] dist {0, 1};
  }
  constraint state_fixed_array_element_subject {
    state_fixed[1] dist {0, 1};
  }
  constraint state_fixed_array_foreach_subject {
    foreach (state_fixed[i]) state_fixed[i] dist {0, 1};
  }
  constraint direct_rand_control { r dist {0, 1}; }
endclass

module main;
  int state;
  int value;

  initial begin
    std::randomize(value) with { state dist {0, 1}; };
    std::randomize() with { state dist {0, 1}; };
  end
endmodule
