// A packed array of enums is one integral class property. Its constraint
// variable must use the property's 16-bit width, including on writeback.
typedef enum logic [3:0] { MuBi4False = 4'h9 } mubi4_t;
typedef mubi4_t [3:0] mubi_hintables_t;
parameter mubi_hintables_t IdleAllBusy = {4{MuBi4False}};

class packed_rand_case;
  rand mubi_hintables_t idle;
  constraint all_busy_c { idle == IdleAllBusy; }
endclass

class packed_state_case;
  mubi_hintables_t current;
  rand bit flag;
  function new(); current = IdleAllBusy; endfunction
  constraint state_c { current == IdleAllBusy; flag == 1'b1; }
endclass

class unpacked_control;
  rand bit [3:0] words[2];
  constraint words_c { words[0] == 4'h5; words[1] == 4'ha; }
endclass

module test;
  initial begin
    packed_rand_case a;
    packed_state_case b;
    unpacked_control c;
    a = new(); b = new(); c = new();
    if (!a.randomize() || a.idle !== IdleAllBusy) $fatal(1, "packed rand property");
    if (!b.randomize() || b.flag !== 1'b1 || b.current !== IdleAllBusy)
      $fatal(1, "packed state property");
    if (!c.randomize() || c.words[0] !== 4'h5 || c.words[1] !== 4'ha)
      $fatal(1, "unpacked control");
    $display("PASSED");
  end
endmodule
