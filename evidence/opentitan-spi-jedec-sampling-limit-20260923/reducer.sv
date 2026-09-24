// IEEE 1800-2017/2023 18.6.3: randomize() may fail only when its
// constraints are infeasible; failed randomization retains prior values.
class bounded_field;
  rand bit [63:0] value;
  int unsigned m_size;

  constraint field_fits { value < (64'h1 << m_size); }

  function new(int unsigned size);
    m_size = size;
  endfunction
endclass

class jedec_like_reg;
  rand bounded_field id;
  rand bounded_field mf;

  function new();
    id = new(16);
    mf = new(8);
  endfunction
endclass

class sized_reg;
  rand bounded_field f;

  function new(int unsigned size);
    f = new(size);
  endfunction
endclass

class impossible_field extends bounded_field;
  constraint impossible { value < 8; value > 12; }

  function new();
    super.new(8);
  endfunction
endclass

class impossible_reg;
  rand impossible_field f;

  function new();
    f = new();
  endfunction
endclass

module reducer;
  initial begin
    jedec_like_reg jedec = new();
    sized_reg at_limit = new(10);
    sized_reg over_limit = new(11);
    impossible_reg unsat = new();
    bit [63:0] previous;
    bit jedec_ok, limit_ok, over_limit_ok, unsat_ok;

    jedec_ok = jedec.randomize();
    limit_ok = at_limit.randomize();
    over_limit_ok = over_limit.randomize();
    unsat.f.value = 5;
    previous = unsat.f.value;
    unsat_ok = unsat.randomize();

    $display("nested 16/8 randomize=%0d", jedec_ok);
    $display("nested size-10 randomize=%0d", limit_ok);
    $display("nested size-11 randomize=%0d", over_limit_ok);
    $display("impossible randomize=%0d retained=%0d", unsat_ok,
             unsat.f.value == previous);

    if (!jedec_ok || !limit_ok || !over_limit_ok || unsat_ok ||
        unsat.f.value != previous)
      $fatal(1, "constraint sampling acceptance failed");
    $display("PASS");
    $finish;
  end
endmodule
