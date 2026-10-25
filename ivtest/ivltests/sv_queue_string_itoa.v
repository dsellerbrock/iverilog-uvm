module sv_queue_string_itoa;
  string q[$];
  initial begin
    q.push_back("");
    q[0].itoa(99);
    if (q[0] != "99")
      $fatal(1, "queue string itoa failed: [%s]", q[0]);
    $display("PASSED");
  end
endmodule
