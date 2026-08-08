// IEEE 1800-2017 10.4.2: a nonblocking assignment captures its RHS and
// class/interface receiver when the statement executes, then updates the
// selected variable in the NBA region. Constant fields of one packed property
// must merge at NBA execution so disjoint writes survive and later overlapping
// writes win in source order.
typedef struct packed {
  logic [3:0] hi;
  logic [3:0] lo;
} nba_pair_t;

interface nba_field_if;
  nba_pair_t bus;
endinterface

class nba_field_cfg;
  virtual nba_field_if vif;
endclass

class nba_field_holder;
  nba_pair_t pair;
endclass

class nba_field_outer;
  nba_field_holder child;
endclass

module sv_nba_property_field;
  nba_field_if if0();
  nba_field_if if1();
  nba_field_cfg cfg;
  nba_field_holder obj;
  nba_field_outer outer;
  logic [3:0] rhs;
  bit nested_wait_woke;
  bit vif_event_woke;
  int errors;

  task automatic drive_vif(nba_field_cfg use_cfg,
                           logic [3:0] hi, logic [3:0] lo);
    use_cfg.vif.bus.hi <= hi;
    use_cfg.vif.bus.lo <= lo;
  endtask

  initial begin
    cfg = new;
    obj = new;
    outer = new;
    outer.child = new;
    cfg.vif = if0;

    // Disjoint updates merge at NBA execution; the later overlapping update
    // wins. Neither Active nor Inactive may observe an early update.
    obj.pair = 8'ha5;
    obj.pair.hi <= 4'h1;
    obj.pair.lo <= 4'h2;
    obj.pair.hi <= 4'h3;
    if (obj.pair !== 8'ha5) begin
      $display("F1 active=%h", obj.pair);
      errors++;
    end
    #0;
    if (obj.pair !== 8'ha5) begin
      $display("F2 inactive=%h", obj.pair);
      errors++;
    end
    #1;
    if (obj.pair !== 8'h32) begin
      $display("F3 merged=%h", obj.pair);
      errors++;
    end

    // A whole-property update and a later field update are ordered NBA
    // events. Reading the property only when the field event executes avoids
    // clobbering the whole update with an Active-region snapshot.
    obj.pair = 8'h00;
    obj.pair <= 8'h12;
    obj.pair.hi <= 4'hf;
    #1;
    if (obj.pair !== 8'hf2) begin
      $display("F4 whole-field=%h", obj.pair);
      errors++;
    end
    obj.pair = 8'h00;
    obj.pair.lo <= 4'he;
    obj.pair <= 8'h34;
    #1;
    if (obj.pair !== 8'h34) begin
      $display("F5 field-whole=%h", obj.pair);
      errors++;
    end

    // The selected receiver and RHS are snapshots. Rebinding cfg.vif and
    // changing rhs after scheduling must not redirect or alter the update.
    if0.bus = 8'ha5;
    if1.bus = 8'h5a;
    rhs = 4'h7;
    fork
      begin
        @(if0.bus);
        vif_event_woke = 1;
      end
    join_none
    #0;
    cfg.vif.bus.hi <= rhs;
    cfg.vif.bus.lo <= 4'h6;
    cfg.vif = if1;
    rhs = 4'h9;
    #1;
    if (if0.bus !== 8'h76 || if1.bus !== 8'h5a || !vif_event_woke) begin
      $display("F6 capture if0=%h if1=%h woke=%b",
               if0.bus, if1.bus, vif_event_woke);
      errors++;
    end

    // The OpenTitan driver shape is a task writing several fields through a
    // nested cfg.vif receiver.
    cfg.vif = if1;
    if1.bus = 8'h00;
    drive_vif(cfg, 4'hc, 4'hd);
    if (if1.bus !== 8'h00) begin
      $display("F7 task-active=%h", if1.bus);
      errors++;
    end
    #1;
    if (if1.bus !== 8'hcd) begin
      $display("F8 task-nba=%h", if1.bus);
      errors++;
    end

    // Constant delayed field updates retain the same merge semantics.
    obj.pair = 8'h12;
    obj.pair.hi <= #2 4'ha;
    obj.pair.lo <= #2 4'hb;
    #1;
    if (obj.pair !== 8'h12) begin
      $display("F9 delayed-early=%h", obj.pair);
      errors++;
    end
    #2;
    if (obj.pair !== 8'hab) begin
      $display("F10 delayed-late=%h", obj.pair);
      errors++;
    end

    // A nested class receiver wakes a wait expression rooted at the outer
    // object when the scheduled field update matures.
    outer.child.pair = 8'h05;
    fork
      begin
        wait (outer.child.pair.hi === 4'h8);
        nested_wait_woke = 1;
      end
    join_none
    #0;
    outer.child.pair.hi <= 4'h8;
    #1;
    if (outer.child.pair !== 8'h85 || !nested_wait_woke) begin
      $display("F11 nested=%h woke=%b",
               outer.child.pair, nested_wait_woke);
      errors++;
    end

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED %0d", errors);
    $finish;
  end
endmodule
