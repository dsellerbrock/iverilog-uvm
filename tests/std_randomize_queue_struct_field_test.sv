// IEEE 1800-2017 18.12: a scope-randomized index may select an integral
// member from the current contents of a queue of unpacked structs.
module std_randomize_queue_struct_field_test;
  class chooser;
    typedef struct {
      string name;
      bit    enabled;
    } desc_t;

    desc_t choices[$] = '{'{"off0", 0},
                           '{"on1",  1},
                           '{"off2", 0},
                           '{"on3",  1}};
    bit require_enabled = 1;

    task run;
      repeat (12) begin
        int unsigned idx;
        if (!std::randomize(idx) with {
              idx < choices.size();
              require_enabled -> choices[idx].enabled;
            }) begin
          $display("FAIL: queue-field std::randomize returned false");
          $finish;
        end
        if (idx >= choices.size() || !choices[idx].enabled) begin
          $display("FAIL: invalid choice idx=%0d", idx);
          $finish;
        end
      end
      $display("PASS: scope randomize runtime queue-struct field");
    endtask
  endclass

  initial begin
    chooser c = new;
    c.run();
    $finish;
  end
endmodule
