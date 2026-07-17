// SPDX-License-Identifier: Apache-2.0
//
// UCIe sideband bump bring-up monitor
// ------------------------------------
// Purpose:
//   A deliberately small, passive monitor used to validate customer wiring,
//   sampling edge, bit order and 64-UI word reconstruction before integrating
//   the full UCIe sideband decoder/checker.
//
// Scope:
//   * One CKSB/DATASB observation point per monitor instance.
//   * Race-reduced sampling through a clocking block with input #1step.
//   * One bit per selected clock edge; D0 is stored in raw_word[0].
//   * Publishes every completed 64-bit word through word_ap.
//   * Reports X/Z, clock-period deviations and interrupted partial words.
//   * Recognizes 64'h5555... and 64'haaaa... as training-pattern hints.
//   * Does NOT decode packets, select Advanced Package repair paths, perform
//     request/completion checking or compare two dies.
//
// Recommended first integration:
//   Instantiate four independent observation points:
//     A_TX: Die A TXDATASB sampled by Die A TXCKSB
//     B_RX: Die B RXDATASB sampled by Die B RXCKSB
//     B_TX: Die B TXDATASB sampled by Die B TXCKSB
//     A_RX: Die A RXDATASB sampled by Die A RXCKSB
//
// Top-level example for A_TX:
//
//   ucie_sb_bringup_if a_tx_sb_bringup_if (
//     .mon_reset_n (link_reset_n),
//     .CKSB        (die_a.TXCKSB),
//     .DATASB      (die_a.TXDATASB)
//   );
//
//   initial begin
//     uvm_config_db#(virtual ucie_sb_bringup_if)::set(
//       null, "uvm_test_top.env.a_tx_mon", "vif", a_tx_sb_bringup_if);
//     // Ensure all config_db::set calls execute before the existing run_test().
//   end
//
// Environment example:
//
//   import ucie_sb_bringup_pkg::*;
//   ucie_sb_bringup_cfg cfg;
//   ucie_sb_bringup_monitor a_tx_mon;
//
//   cfg = ucie_sb_bringup_cfg::type_id::create("cfg");
//   cfg.observation_point = "A_TX_PRIMARY";
//   cfg.sample_edge       = UCIE_SB_BRINGUP_NEGEDGE;
//   cfg.ui_period         = 1250ps;
//   uvm_config_db#(ucie_sb_bringup_cfg)::set(
//     this, "a_tx_mon", "cfg", cfg);
//   a_tx_mon = ucie_sb_bringup_monitor::type_id::create("a_tx_mon", this);
//
// Compile this file once, after the customer-selected UVM library and before
// any package that imports ucie_sb_bringup_pkg. Do not compile a second UVM
// library alongside the UVM library used by Synopsys SVT.

`ifndef UCIE_SB_BUMP_BRINGUP_MONITOR_SV
`define UCIE_SB_BUMP_BRINGUP_MONITOR_SV

`include "uvm_macros.svh"

interface ucie_sb_bringup_if (
  input logic mon_reset_n,
  input logic CKSB,
  input logic DATASB
);
  timeunit 1ps;
  timeprecision 1ps;

  // UCIe 2.0 bring-up uses negedge by default. The posedge block exists only
  // to help diagnose an integration whose launch/sample convention is not yet
  // confirmed. Production use should lock the edge to the protocol setting.
  clocking mon_neg_cb @(negedge CKSB);
    default input #1step;
    input mon_reset_n;
    input DATASB;
  endclocking

  clocking mon_pos_cb @(posedge CKSB);
    default input #1step;
    input mon_reset_n;
    input DATASB;
  endclocking

  modport MONITOR (
    input mon_reset_n,
    input CKSB,
    input DATASB
  );
endinterface

package ucie_sb_bringup_pkg;
  timeunit 1ps;
  timeprecision 1ps;

  import uvm_pkg::*;

  typedef enum int unsigned {
    UCIE_SB_BRINGUP_NEGEDGE = 0,
    UCIE_SB_BRINGUP_POSEDGE = 1
  } ucie_sb_bringup_edge_e;

  class ucie_sb_bringup_cfg extends uvm_object;
    int unsigned             module_id             = 0;
    string                   observation_point     = "UNNAMED";
    ucie_sb_bringup_edge_e   sample_edge           = UCIE_SB_BRINGUP_NEGEDGE;

    time                     ui_period             = 1250ps;
    real                     clock_tolerance_pct   = 10.0;

    bit                      check_clock           = 1'b1;
    bit                      check_xz              = 1'b1;
    bit                      check_partial_word    = 1'b1;
    bit                      strict_checks         = 1'b0;

    int unsigned             max_words_to_log      = 32;
    bit                      log_each_bit          = 1'b0;
    int unsigned             max_bits_to_log       = 128;

    `uvm_object_utils(ucie_sb_bringup_cfg)

    function new(string name = "ucie_sb_bringup_cfg");
      super.new(name);
    endfunction
  endclass

  class ucie_sb_bringup_word extends uvm_sequence_item;
    int unsigned            module_id;
    string                  observation_point;
    ucie_sb_bringup_edge_e  sample_edge;
    int unsigned            epoch;
    longint unsigned        word_index;

    logic [63:0]            raw_word;
    bit   [63:0]            unknown_mask;
    bit                     training_55;
    bit                     training_aa;

    time                    first_bit_time;
    time                    last_bit_time;
    int                     gap_ui;
    bit                     gap_valid;

    `uvm_object_utils(ucie_sb_bringup_word)

    function new(string name = "ucie_sb_bringup_word");
      super.new(name);
    endfunction

    virtual function void do_copy(uvm_object rhs);
      ucie_sb_bringup_word rhs_word;
      super.do_copy(rhs);
      if (!$cast(rhs_word, rhs)) begin
        `uvm_fatal("UCIE_SB_BRINGUP_COPY",
          "ucie_sb_bringup_word::do_copy type mismatch")
      end
      module_id         = rhs_word.module_id;
      observation_point = rhs_word.observation_point;
      sample_edge       = rhs_word.sample_edge;
      epoch             = rhs_word.epoch;
      word_index        = rhs_word.word_index;
      raw_word          = rhs_word.raw_word;
      unknown_mask      = rhs_word.unknown_mask;
      training_55       = rhs_word.training_55;
      training_aa       = rhs_word.training_aa;
      first_bit_time    = rhs_word.first_bit_time;
      last_bit_time     = rhs_word.last_bit_time;
      gap_ui            = rhs_word.gap_ui;
      gap_valid         = rhs_word.gap_valid;
    endfunction

    virtual function string convert2string();
      string gap_text;
      if (gap_valid) gap_text = $sformatf("%0d", gap_ui);
      else           gap_text = "NA";
      return $sformatf(
        "module=%0d point=%s epoch=%0d word=%0d edge=%s raw=%016h xmask=%016h gap_ui=%s train55=%0b trainAA=%0b",
        module_id, observation_point, epoch, word_index, sample_edge.name(),
        raw_word, unknown_mask, gap_text, training_55, training_aa);
    endfunction
  endclass

  class ucie_sb_bringup_monitor extends uvm_monitor;
    `uvm_component_utils(ucie_sb_bringup_monitor)

    uvm_analysis_port #(ucie_sb_bringup_word) word_ap;

    virtual ucie_sb_bringup_if vif;
    ucie_sb_bringup_cfg cfg;

    protected logic [63:0] current_word;
    protected bit   [63:0] current_unknown_mask;
    protected int unsigned bit_index;
    protected int unsigned epoch;
    protected longint unsigned word_index;

    protected realtime word_start_rt;
    protected realtime previous_word_start_rt;
    protected realtime last_edge_rt;
    protected bit have_previous_word;

    protected longint unsigned sampled_edge_count;
    protected longint unsigned completed_word_count;
    protected longint unsigned xz_sample_count;
    protected longint unsigned clock_error_count;
    protected longint unsigned partial_word_count;
    protected longint unsigned reset_count;
    protected int unsigned logged_word_count;
    protected int unsigned logged_bit_count;

    function new(string name = "ucie_sb_bringup_monitor",
                 uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      word_ap = new("word_ap", this);

      if (!uvm_config_db#(virtual ucie_sb_bringup_if)::get(
            this, "", "vif", vif)) begin
        `uvm_fatal("UCIE_SB_BRINGUP_CFG",
          "Missing virtual interface config key 'vif'")
      end

      if (!uvm_config_db#(ucie_sb_bringup_cfg)::get(
            this, "", "cfg", cfg)) begin
        cfg = ucie_sb_bringup_cfg::type_id::create("cfg");
        `uvm_info("UCIE_SB_BRINGUP_CFG",
          "No cfg supplied; using negedge/1250ps bring-up defaults", UVM_LOW)
      end

      if (cfg.ui_period == 0) begin
        `uvm_fatal("UCIE_SB_BRINGUP_CFG",
          "cfg.ui_period must be greater than zero")
      end
      if ((cfg.clock_tolerance_pct < 0.0) ||
          (cfg.clock_tolerance_pct >= 100.0)) begin
        `uvm_fatal("UCIE_SB_BRINGUP_CFG",
          "cfg.clock_tolerance_pct must be in [0,100)")
      end

      epoch = 0;
      word_index = 0;
      sampled_edge_count = 0;
      completed_word_count = 0;
      xz_sample_count = 0;
      clock_error_count = 0;
      partial_word_count = 0;
      reset_count = 0;
      logged_word_count = 0;
      logged_bit_count = 0;
      clear_partial_state();
    endfunction

    virtual task run_phase(uvm_phase phase);
      fork
        sample_stream();
        watch_reset();
      join
    endtask

    protected task sample_stream();
      if (cfg.sample_edge == UCIE_SB_BRINGUP_NEGEDGE) begin
        forever begin
          @(vif.mon_neg_cb);
          if ((vif.mon_neg_cb.mon_reset_n === 1'b1) &&
              (vif.mon_reset_n === 1'b1)) begin
            consume_sample(vif.mon_neg_cb.DATASB, $realtime);
          end
        end
      end
      else begin
        forever begin
          @(vif.mon_pos_cb);
          if ((vif.mon_pos_cb.mon_reset_n === 1'b1) &&
              (vif.mon_reset_n === 1'b1)) begin
            consume_sample(vif.mon_pos_cb.DATASB, $realtime);
          end
        end
      end
    endtask

    protected task watch_reset();
      forever begin
        @(negedge vif.mon_reset_n);
        if (bit_index != 0) begin
          partial_word_count++;
          if (cfg.check_partial_word) begin
            report_problem("UCIE_SB_BRINGUP_RESET",
              $sformatf("point=%s reset discarded partial word with %0d bit(s)",
                cfg.observation_point, bit_index));
          end
        end
        reset_count++;
        epoch++;
        word_index = 0;
        clear_partial_state();
      end
    endtask

    protected function void clear_partial_state();
      current_word = '0;
      current_unknown_mask = '0;
      bit_index = 0;
      word_start_rt = 0.0;
      previous_word_start_rt = 0.0;
      last_edge_rt = 0.0;
      have_previous_word = 1'b0;
    endfunction

    protected function void consume_sample(logic sampled_data,
                                           realtime sample_rt);
      realtime delta_rt;
      realtime min_period_rt;
      realtime max_period_rt;
      realtime framing_loss_rt;
      bit restart_word;

      sampled_edge_count++;
      restart_word = 1'b0;
      min_period_rt = realtime'(cfg.ui_period) *
                      (1.0 - (cfg.clock_tolerance_pct / 100.0));
      max_period_rt = realtime'(cfg.ui_period) *
                      (1.0 + (cfg.clock_tolerance_pct / 100.0));
      framing_loss_rt = realtime'(cfg.ui_period) * 1.5;

      if (bit_index != 0) begin
        delta_rt = sample_rt - last_edge_rt;
        if (cfg.check_clock &&
            ((delta_rt < min_period_rt) || (delta_rt > max_period_rt))) begin
          clock_error_count++;
          report_problem("UCIE_SB_BRINGUP_CLK",
            $sformatf("point=%s bit=%0d clock period=%0.3f ps; expected=%0t +/- %0.2f%%",
              cfg.observation_point, bit_index, delta_rt, cfg.ui_period,
              cfg.clock_tolerance_pct));
        end

        if (delta_rt > framing_loss_rt) begin
          partial_word_count++;
          if (cfg.check_partial_word) begin
            report_problem("UCIE_SB_BRINGUP_PARTIAL",
              $sformatf("point=%s long clock gap interrupted a word after %0d bit(s); current edge becomes new D0",
                cfg.observation_point, bit_index));
          end
          restart_word = 1'b1;
        end
      end

      if ((bit_index == 0) || restart_word) begin
        current_word = '0;
        current_unknown_mask = '0;
        bit_index = 0;
        word_start_rt = sample_rt;
      end

      current_word[bit_index] = sampled_data;
      if ($isunknown(sampled_data)) begin
        current_unknown_mask[bit_index] = 1'b1;
        xz_sample_count++;
        if (cfg.check_xz) begin
          report_problem("UCIE_SB_BRINGUP_XZ",
            $sformatf("point=%s sampled X/Z at bit=%0d epoch=%0d word=%0d",
              cfg.observation_point, bit_index, epoch, word_index));
        end
      end

      if (cfg.log_each_bit &&
          ((cfg.max_bits_to_log == 0) ||
           (logged_bit_count < cfg.max_bits_to_log))) begin
        logged_bit_count++;
        `uvm_info("UCIE_SB_BRINGUP_BIT",
          $sformatf("point=%s epoch=%0d word=%0d bit=%0d value=%b time=%0t",
            cfg.observation_point, epoch, word_index, bit_index,
            sampled_data, time'(sample_rt)), UVM_HIGH)
      end

      last_edge_rt = sample_rt;
      bit_index++;

      if (bit_index == 64) begin
        publish_word(sample_rt);
        previous_word_start_rt = word_start_rt;
        have_previous_word = 1'b1;
        current_word = '0;
        current_unknown_mask = '0;
        bit_index = 0;
      end
    endfunction

    protected function void publish_word(realtime sample_rt);
      ucie_sb_bringup_word item;

      item = ucie_sb_bringup_word::type_id::create("bringup_word");
      item.module_id = cfg.module_id;
      item.observation_point = cfg.observation_point;
      item.sample_edge = cfg.sample_edge;
      item.epoch = epoch;
      item.word_index = word_index;
      item.raw_word = current_word;
      item.unknown_mask = current_unknown_mask;
      item.training_55 = ((current_unknown_mask == '0) &&
                          (current_word === 64'h5555_5555_5555_5555));
      item.training_aa = ((current_unknown_mask == '0) &&
                          (current_word === 64'haaaa_aaaa_aaaa_aaaa));
      item.first_bit_time = time'(word_start_rt);
      item.last_bit_time = time'(sample_rt);
      item.gap_valid = have_previous_word;
      item.gap_ui = 0;
      if (have_previous_word) begin
        item.gap_ui = $rtoi(
          ((word_start_rt - previous_word_start_rt) /
            realtime'(cfg.ui_period)) + 0.5) - 64;
      end

      word_ap.write(item);
      completed_word_count++;

      if ((cfg.max_words_to_log == 0) ||
          (logged_word_count < cfg.max_words_to_log)) begin
        logged_word_count++;
        `uvm_info("UCIE_SB_BRINGUP_WORD", item.convert2string(), UVM_LOW)
      end

      word_index++;
    endfunction

    protected function void report_problem(string id, string message);
      if (cfg.strict_checks) begin
        `uvm_error(id, message)
      end
      else begin
        `uvm_warning(id, message)
      end
    endfunction

    virtual function void report_phase(uvm_phase phase);
      super.report_phase(phase);

      if (bit_index != 0) begin
        partial_word_count++;
        if (cfg.check_partial_word) begin
          report_problem("UCIE_SB_BRINGUP_END",
            $sformatf("point=%s simulation ended with %0d/64 bit(s) in a partial word",
              cfg.observation_point, bit_index));
        end
      end

      `uvm_info("UCIE_SB_BRINGUP_SUMMARY",
        $sformatf("module=%0d point=%s edge=%s epochs=%0d resets=%0d sampled_edges=%0d completed_words=%0d xz_samples=%0d clock_errors=%0d partial_words=%0d",
          cfg.module_id, cfg.observation_point, cfg.sample_edge.name(), epoch + 1,
          reset_count, sampled_edge_count, completed_word_count,
          xz_sample_count, clock_error_count, partial_word_count), UVM_NONE)
    endfunction
  endclass

endpackage

`endif // UCIE_SB_BUMP_BRINGUP_MONITOR_SV
