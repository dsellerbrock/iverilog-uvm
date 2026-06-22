// Associative array keyed by a CLASS-SCOPED type, e.g.
//   uvm_reg_data_t r[my_class::some_enum_e];
// (the aon_timer_scoreboard "loosely-timed registers" pattern).  A
// class-scoped type name "class::member" is syntactically ambiguous with a
// class-scoped static-reference expression; the lexer resolves it to a
// single class-scoped-type token so it lands in data_type positions (here,
// the assoc index type) instead of being mis-parsed as a size expression.
//
// Also checks that this does NOT disturb the pervasive UVM factory idiom
// "klass::type_id::create(...)" (a longer scoped name that must stay a
// multi-token reference) or class-scoped static values.
class keys;
  typedef enum { K_A, K_B, K_C } key_e;
endclass

class regfile;
  // class-member assoc keyed by the class-scoped enum type
  int data[keys::key_e];
  function void put(keys::key_e k, int v); data[k] = v; endfunction
  function int  get(keys::key_e k);        return data[k]; endfunction
endclass

class statics;
  static const int WIDTH = 12;
  typedef enum { S_X, S_Y } s_e;
endclass

module assoc_class_scoped_index_test;
  initial begin
    regfile rf = new();
    keys::key_e k = keys::K_B;     // class-scoped type decl + value
    statics::s_e sv;
    int w;

    rf.put(keys::K_A, 10);
    rf.put(keys::K_B, 20);
    rf.put(keys::K_C, 30);

    sv = statics::S_Y;             // class-scoped enum value (no merge)
    w  = statics::WIDTH;           // class-scoped static const (no merge)

    if (rf.get(keys::K_A) == 10 &&
        rf.get(k)         == 20 &&
        rf.get(keys::K_C) == 30 &&
        rf.data.size()    == 3  &&
        sv == statics::S_Y && w == 12)
      $display("PASS size=%0d WIDTH=%0d", rf.data.size(), w);
    else
      $display("FAIL a=%0d b=%0d c=%0d size=%0d w=%0d",
               rf.get(keys::K_A), rf.get(k), rf.get(keys::K_C),
               rf.data.size(), w);
    $finish;
  end
endmodule
