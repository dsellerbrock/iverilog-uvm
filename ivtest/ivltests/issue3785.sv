module issue3785;
  typedef struct packed { logic [1:0] n; logic valid; } pair_t;
  typedef enum logic [1:0] { READY = 3 } data_t;
  typedef struct packed { logic carry; data_t data; } other_t;
  typedef struct packed { pair_t pair; logic pad; } wrapper_t;
  localparam wrapper_t WRAPPED = 4'b111_0;

  class holder;
    pair_t pair;
  endclass

  int calls;
  int index;
  pair_t [1:0] packed_pairs;
  pair_t fixed_pairs[2];
  pair_t dynamic_pairs[];
  wrapper_t wrappers[2];
  logic [5:0] plain;
  holder obj;

  function automatic pair_t make_pair(input pair_t value = 3'b111);
    calls++;
    return value;
  endfunction

  function automatic other_t make_other();
    return 3'b111;
  endfunction

  initial begin
    string formatted;
    formatted = $sformatf("%p", make_pair());
    $display("call=%s count=%0d", formatted, calls);
    if (formatted != "'{n:3, valid:1}" || calls != 1)
      $fatal(1, "packed function result or call count");

    // The same stack position and width can carry a different structure.
    $display("other=%p", make_other());
    $display("four-state=%p", make_pair(3'b11z));
    $display("numeric=%0d binary=%b", make_pair(), make_pair());
    if (calls != 4)
      $fatal(1, "packed function was evaluated more than once per argument");

    index = 1;
    packed_pairs = 6'b111_100;
    fixed_pairs[1] = 3'b101;
    dynamic_pairs = new[2];
    dynamic_pairs[1] = 3'b011;
    wrappers[1] = 4'b110_0;
    obj = new;
    obj.pair = 3'b111;
    plain = 6'b111_010;

    $display("packed=%p indexed=%p", packed_pairs[1], packed_pairs[index]);
    $display("fixed=%p dynamic=%p member=%p",
             fixed_pairs[index], dynamic_pairs[index], wrappers[1].pair);
    $display("property=%p numeric=%0d binary=%b", obj.pair, obj.pair, obj.pair);
    $display("part=%p indexed-part=%p concat=%p member-bits=%p",
             plain[5:3], plain[5-:3], {plain[5:4], plain[3]}, wrappers[1][3:1]);

    // These handles sample the current value in the Postponed region.
    $strobe("live-select=%p live-property=%p constant-select=%p",
            packed_pairs[1], obj.pair, WRAPPED.pair);
    packed_pairs[1] = 3'b010;
    obj.pair = 3'b001;
  end
endmodule
