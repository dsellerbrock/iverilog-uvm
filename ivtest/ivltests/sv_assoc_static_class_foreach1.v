class setting_t;
  int value;
  static setting_t settings[$];
endclass

module test;
  initial begin
    int sum;
    setting_t first;
    setting_t second;

    sum = 0;
    first = new();
    second = new();
    first.value = 1;
    second.value = 2;

    setting_t::settings.delete();
    setting_t::settings.push_back(first);
    setting_t::settings.push_back(second);

    foreach (setting_t::settings[i]) begin
      sum += setting_t::settings[i].value;
    end

    if (sum == 3) begin
      $display("PASSED");
    end else begin
      $display("STATIC_FAIL %0d", sum);
      $finish(1);
    end
  end
endmodule
