module test;

  class key_t;
  endclass

  class evt_t;
    int waiters;
  endclass

  class holder_t;
    evt_t m_events[key_t];

    function void bump(key_t key);
      if (!m_events.exists(key))
        m_events[key] = new;

      if (!m_events.exists(key)) begin
        $display("FAILED: exists after create");
        $finish(1);
      end

      m_events[key].waiters++;
      if (m_events[key].waiters != 1) begin
        $display("FAILED: incr got %0d", m_events[key].waiters);
        $finish(1);
      end

      if (!m_events.exists(key)) begin
        $display("FAILED: exists after incr");
        $finish(1);
      end

      m_events[key].waiters--;
      if (m_events[key].waiters != 0) begin
        $display("FAILED: decr got %0d", m_events[key].waiters);
        $finish(1);
      end

      if (m_events[key].waiters == 0)
        m_events.delete(key);
    endfunction
  endclass

  initial begin
    holder_t h;
    key_t key;

    h = new;
    key = new;

    h.bump(key);
    if (h.m_events.exists(key)) begin
      $display("FAILED: delete");
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
