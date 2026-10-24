module sv_chandle_restrictions_fail(input chandle port_handle);
  typedef struct packed { chandle member; } packed_chandle_t;
  typedef union { chandle member; int value; } untagged_chandle_t;

  packed_chandle_t packed_value;
  untagged_chandle_t union_value;
endmodule
