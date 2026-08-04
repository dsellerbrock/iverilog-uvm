// A non-rand queue's size is object state at randomize() time. Verify that
// a declared class constraint reads the live size, including after resize,
// and that an unsatisfiable solve leaves the rand property unchanged.
module main;
  class item;
  endclass

  class selector;
    protected item sequences[$];
    rand int unsigned select_rand;
    int unsigned target;

    constraint force_target {
      select_rand == target;
    }
    constraint valid_rand_selection {
      select_rand inside {[0:sequences.size()-1]};
    }

    function void set_count(int unsigned count);
      item elem;
      sequences.delete();
      repeat (count) begin
        elem = new;
        sequences.push_back(elem);
      end
    endfunction
  endclass

  initial begin
    automatic selector s = new;
    int ok;

    s.set_count(3);
    s.target = 2;
    s.select_rand = 99;
    ok = s.randomize();
    if (!ok || s.select_rand != 2) begin
      $display("FAILED -- size=3 target=2 ok=%0d select=%0d", ok,
               s.select_rand);
      $finish;
    end

    s.set_count(2);
    s.target = 2;
    s.select_rand = 77;
    ok = s.randomize();
    if (ok || s.select_rand != 77) begin
      $display("FAILED -- size=2 target=2 ok=%0d select=%0d", ok,
               s.select_rand);
      $finish;
    end

    $display("PASSED");
  end
endmodule
