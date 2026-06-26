`ifndef UCIE_RDI_SIMPLE_MONITOR_SVH
`define UCIE_RDI_SIMPLE_MONITOR_SVH

`ifndef UCIE_RDI_SIMPLE_ACTIVE_VALUE
`define UCIE_RDI_SIMPLE_ACTIVE_VALUE 4'h1
`endif

class ucie_rdi_simple_monitor extends uvm_monitor;
  `uvm_component_utils(ucie_rdi_simple_monitor)

  svt_ucie_d2d_vif rdi_vif;
  ucie_rdi_simple_side_e side;
  uvm_analysis_port #(ucie_rdi_simple_item) ap;

  bit [3:0] active_state_value = `UCIE_RDI_SIMPLE_ACTIVE_VALUE;
  bit [3:0] l1_state_value;
  bit [3:0] l2_state_value;
  bit [3:0] retrain_state_value;
  bit [3:0] linkerror_state_value;
  bit       l1_state_valid;
  bit       l2_state_valid;
  bit       retrain_state_valid;
  bit       linkerror_state_valid;
  ucie_rdi_check_mode_e check_mode = UCIE_RDI_CHECK_BASIC;
  bit       active_seen;
  bit       log_each_item = 1'b0;
  bit       log_sample_values = 1'b0;
  bit       enable_protocol_checks = 1'b1;
  bit       check_x_on_control = 1'b1;
  bit       check_tx_stable_backpressure = 1'b1;
  bit       check_no_data_before_active = 1'b0;
  bit       check_rdi_state_sequence = 1'b0;
  bit       check_error_signals = 1'b0;
  bit       check_wake_clock_stall = 1'b0;
  bit       error_signal_fatal_is_error = 1'b1;
  int unsigned rdi_ctrl_timeout_limit = 1024;

  bit                                  tx_hold_active;
  bit [`UCIE_RDI_SIMPLE_DATA_BITS-1:0] tx_hold_data;
  time                                 tx_hold_start_time;
  int unsigned                         protocol_error_count;
  int unsigned                         tx_sample_count;
  int unsigned                         rx_sample_count;
  int unsigned                         state_transition_count;
  int unsigned                         error_signal_count;
  int unsigned                         rdi_ctrl_timeout_count;
  bit                                  state_seen;
  bit [3:0]                            last_state;
  bit                                  pending_l1_req;
  bit                                  pending_l2_req;
  bit                                  pending_retrain_req;

`ifdef UCIE_RDI_SIMPLE_HAS_ERROR_SIGNALS
  bit last_lp_linkerror;
  bit last_pl_error;
  bit last_pl_trainerror;
  bit last_pl_nferror;
  bit last_pl_cerror;
`endif

`ifdef UCIE_RDI_SIMPLE_HAS_PM_STALL_SIGNALS
  bit wake_pending;
  bit clk_pending;
  bit stall_pending;
  int unsigned wake_timer;
  int unsigned clk_timer;
  int unsigned stall_timer;
`endif

  function new(string name = "ucie_rdi_simple_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    string side_name;

    super.build_phase(phase);

    if (!uvm_config_db#(ucie_rdi_simple_side_e)::get(this, "", "side", side)) begin
      if (uvm_config_db#(string)::get(this, "", "side_name", side_name)) begin
        if (side_name == "US")
          side = UCIE_RDI_SIMPLE_US;
        else if (side_name == "DS")
          side = UCIE_RDI_SIMPLE_DS;
        else
          `uvm_fatal("RDI_SIMPLE_MON", $sformatf("Unsupported side_name '%s'", side_name))
      end else begin
        `uvm_fatal("RDI_SIMPLE_MON", "side must be set to UCIE_RDI_SIMPLE_US or UCIE_RDI_SIMPLE_DS")
      end
    end

    if (!uvm_config_db#(svt_ucie_d2d_vif)::get(this, "", "rdi_vif", rdi_vif)) begin
      if (side == UCIE_RDI_SIMPLE_US) begin
        if (!uvm_config_db#(svt_ucie_d2d_vif)::get(this, "", "ucie_us_rdi_vif", rdi_vif) &&
            !uvm_config_db#(svt_ucie_d2d_vif)::get(null, "uvm_test_top.ucie_env", "ucie_us_rdi_vif", rdi_vif)) begin
          `uvm_fatal("RDI_SIMPLE_MON", "US monitor cannot get rdi_vif or ucie_us_rdi_vif")
        end
      end else begin
        if (!uvm_config_db#(svt_ucie_d2d_vif)::get(this, "", "ucie_ds_rdi_vif", rdi_vif) &&
            !uvm_config_db#(svt_ucie_d2d_vif)::get(null, "uvm_test_top.ucie_env", "ucie_ds_rdi_vif", rdi_vif)) begin
          `uvm_fatal("RDI_SIMPLE_MON", "DS monitor cannot get rdi_vif or ucie_ds_rdi_vif")
        end
      end
    end

    void'(uvm_config_db#(ucie_rdi_check_mode_e)::get(this, "", "check_mode", check_mode));
    apply_check_mode();

    void'(uvm_config_db#(bit [3:0])::get(this, "", "active_state_value", active_state_value));
    if (uvm_config_db#(bit [3:0])::get(this, "", "l1_state_value", l1_state_value))
      l1_state_valid = 1'b1;
    if (uvm_config_db#(bit [3:0])::get(this, "", "l2_state_value", l2_state_value))
      l2_state_valid = 1'b1;
    if (uvm_config_db#(bit [3:0])::get(this, "", "retrain_state_value", retrain_state_value))
      retrain_state_valid = 1'b1;
    if (uvm_config_db#(bit [3:0])::get(this, "", "linkerror_state_value", linkerror_state_value))
      linkerror_state_valid = 1'b1;
    void'(uvm_config_db#(bit)::get(this, "", "log_each_item", log_each_item));
    void'(uvm_config_db#(bit)::get(this, "", "log_sample_values", log_sample_values));
    void'(uvm_config_db#(bit)::get(this, "", "enable_protocol_checks", enable_protocol_checks));
    void'(uvm_config_db#(bit)::get(this, "", "check_x_on_control", check_x_on_control));
    void'(uvm_config_db#(bit)::get(this, "", "check_tx_stable_backpressure", check_tx_stable_backpressure));
    void'(uvm_config_db#(bit)::get(this, "", "check_no_data_before_active", check_no_data_before_active));
    void'(uvm_config_db#(bit)::get(this, "", "check_rdi_state_sequence", check_rdi_state_sequence));
    void'(uvm_config_db#(bit)::get(this, "", "check_error_signals", check_error_signals));
    void'(uvm_config_db#(bit)::get(this, "", "check_wake_clock_stall", check_wake_clock_stall));
    void'(uvm_config_db#(bit)::get(this, "", "error_signal_fatal_is_error", error_signal_fatal_is_error));
    void'(uvm_config_db#(int unsigned)::get(this, "", "rdi_ctrl_timeout_limit", rdi_ctrl_timeout_limit));
  endfunction

  function void apply_check_mode();
    case (check_mode)
      UCIE_RDI_CHECK_SMOKE: begin
        enable_protocol_checks = 1'b0;
        check_x_on_control = 1'b0;
        check_tx_stable_backpressure = 1'b0;
        check_no_data_before_active = 1'b0;
        check_rdi_state_sequence = 1'b0;
        check_error_signals = 1'b0;
        check_wake_clock_stall = 1'b0;
      end

      UCIE_RDI_CHECK_STRICT: begin
        enable_protocol_checks = 1'b1;
        check_x_on_control = 1'b1;
        check_tx_stable_backpressure = 1'b1;
        check_no_data_before_active = 1'b1;
        check_rdi_state_sequence = 1'b1;
        check_error_signals = 1'b1;
        check_wake_clock_stall = 1'b1;
      end

      default: begin
        enable_protocol_checks = 1'b1;
        check_x_on_control = 1'b1;
        check_tx_stable_backpressure = 1'b1;
        check_no_data_before_active = 1'b0;
        check_rdi_state_sequence = 1'b0;
        check_error_signals = 1'b0;
        check_wake_clock_stall = 1'b0;
      end
    endcase
  endfunction

  task run_phase(uvm_phase phase);
    `uvm_info("RDI_SIMPLE_MON",
              $sformatf("%s monitor started active_state_value=0x%0h",
                        side_to_string(), active_state_value),
              UVM_LOW)

    forever begin
      @(posedge rdi_vif.lclk);

      if (rdi_vif.reset) begin
        reset_protocol_checks();
        continue;
      end

      if (enable_protocol_checks) begin
        check_common_protocol();
        check_rdi_state_tracking();
`ifdef UCIE_RDI_SIMPLE_HAS_ERROR_SIGNALS
        if (check_error_signals)
          check_rdi_error_signals();
`endif
`ifdef UCIE_RDI_SIMPLE_HAS_PM_STALL_SIGNALS
        if (check_wake_clock_stall)
          check_pm_stall_handshakes();
`endif
      end

      if (!is_active()) begin
        active_seen = 1'b0;
        tx_hold_active = 1'b0;

        if (enable_protocol_checks && check_no_data_before_active)
          check_no_data_while_inactive();

        continue;
      end

      if (!active_seen) begin
        active_seen = 1'b1;
        `uvm_info("RDI_SIMPLE_MON",
                  $sformatf("%s RDI ACTIVE observed state=0x%0h inband=%0b",
                            side_to_string(), rdi_vif.pl_state_sts,
                            rdi_vif.pl_inband_pres),
                  UVM_LOW)
      end

      if (enable_protocol_checks)
        check_active_protocol();

      sample_mainband();
    end
  endtask

  function bit is_active();
    return ((rdi_vif.pl_state_sts == active_state_value) &&
            (rdi_vif.pl_inband_pres == 1'b1));
  endfunction

  task sample_mainband();
    ucie_rdi_simple_item item;

    if (rdi_vif.lp_valid && rdi_vif.lp_irdy && rdi_vif.pl_trdy) begin
      item = make_item(UCIE_RDI_SIMPLE_MAINBAND_TX);
      item.data = rdi_vif.lp_data;
      tx_sample_count++;
      ap.write(item);
      log_item(item);
      log_sample("TX", tx_sample_count, item);
    end

    if (rdi_vif.pl_valid) begin
      item = make_item(UCIE_RDI_SIMPLE_MAINBAND_RX);
      item.data = rdi_vif.pl_data;
      rx_sample_count++;
      ap.write(item);
      log_item(item);
      log_sample("RX", rx_sample_count, item);
    end
  endtask

  function void reset_protocol_checks();
    active_seen = 1'b0;
    tx_hold_active = 1'b0;
    tx_hold_data = '0;
    tx_hold_start_time = 0;
    state_seen = 1'b0;
    last_state = '0;
    pending_l1_req = 1'b0;
    pending_l2_req = 1'b0;
    pending_retrain_req = 1'b0;
`ifdef UCIE_RDI_SIMPLE_HAS_ERROR_SIGNALS
    last_lp_linkerror = 1'b0;
    last_pl_error = 1'b0;
    last_pl_trainerror = 1'b0;
    last_pl_nferror = 1'b0;
    last_pl_cerror = 1'b0;
`endif
`ifdef UCIE_RDI_SIMPLE_HAS_PM_STALL_SIGNALS
    wake_pending = 1'b0;
    clk_pending = 1'b0;
    stall_pending = 1'b0;
    wake_timer = 0;
    clk_timer = 0;
    stall_timer = 0;
`endif
  endfunction

  function void check_common_protocol();
    if (check_x_on_control) begin
      if ($isunknown(rdi_vif.pl_state_sts))
        report_protocol_error("pl_state_sts is X/Z");
      if ($isunknown(rdi_vif.pl_inband_pres))
        report_protocol_error("pl_inband_pres is X/Z");
      if ($isunknown(rdi_vif.lp_valid))
        report_protocol_error("lp_valid is X/Z");
      if ($isunknown(rdi_vif.lp_irdy))
        report_protocol_error("lp_irdy is X/Z");
      if ($isunknown(rdi_vif.pl_trdy))
        report_protocol_error("pl_trdy is X/Z");
      if ($isunknown(rdi_vif.pl_valid))
        report_protocol_error("pl_valid is X/Z");
    end
  endfunction

  function void check_no_data_while_inactive();
    if (rdi_vif.lp_valid && rdi_vif.lp_irdy)
      report_protocol_error("lp_valid/lp_irdy asserted before RDI ACTIVE");
    if (rdi_vif.pl_valid)
      report_protocol_error("pl_valid asserted before RDI ACTIVE");
  endfunction

  function void check_active_protocol();
    if (check_tx_stable_backpressure)
      check_tx_backpressure_stability();
  endfunction

  function void check_rdi_state_tracking();
    bit [3:0] cur_state;

    cur_state = rdi_vif.pl_state_sts;

`ifdef UCIE_RDI_SIMPLE_HAS_LP_STATE_REQ
    if (l1_state_valid && (rdi_vif.lp_state_req == l1_state_value))
      pending_l1_req = 1'b1;
    if (l2_state_valid && (rdi_vif.lp_state_req == l2_state_value))
      pending_l2_req = 1'b1;
    if (retrain_state_valid && (rdi_vif.lp_state_req == retrain_state_value))
      pending_retrain_req = 1'b1;
`endif

    if (!state_seen) begin
      state_seen = 1'b1;
      last_state = cur_state;
      return;
    end

    if (cur_state != last_state) begin
      state_transition_count++;
      `uvm_info("RDI_SIMPLE_MON_STATE",
                $sformatf("%s state transition old=0x%0h new=0x%0h time=%0t",
                          side_to_string(), last_state, cur_state, $time),
                UVM_LOW)

      if (check_rdi_state_sequence)
        check_state_transition_legality(last_state, cur_state);

      last_state = cur_state;
    end
  endfunction

  function void check_state_transition_legality(bit [3:0] old_state, bit [3:0] new_state);
    if (l1_state_valid && (new_state == l1_state_value)) begin
`ifdef UCIE_RDI_SIMPLE_HAS_LP_STATE_REQ
      if (!pending_l1_req)
        report_protocol_error($sformatf("L1 state entered without observed L1 request old=0x%0h new=0x%0h",
                                        old_state, new_state));
      pending_l1_req = 1'b0;
`else
      `uvm_info("RDI_SIMPLE_MON_STATE",
                $sformatf("%s L1 state observed old=0x%0h new=0x%0h; request check disabled because UCIE_RDI_SIMPLE_HAS_LP_STATE_REQ is not defined",
                          side_to_string(), old_state, new_state),
                UVM_LOW)
`endif
    end

    if (l2_state_valid && (new_state == l2_state_value)) begin
`ifdef UCIE_RDI_SIMPLE_HAS_LP_STATE_REQ
      if (!pending_l2_req)
        report_protocol_error($sformatf("L2 state entered without observed L2 request old=0x%0h new=0x%0h",
                                        old_state, new_state));
      pending_l2_req = 1'b0;
`else
      `uvm_info("RDI_SIMPLE_MON_STATE",
                $sformatf("%s L2 state observed old=0x%0h new=0x%0h; request check disabled because UCIE_RDI_SIMPLE_HAS_LP_STATE_REQ is not defined",
                          side_to_string(), old_state, new_state),
                UVM_LOW)
`endif
    end

    if (retrain_state_valid && (new_state == retrain_state_value)) begin
`ifdef UCIE_RDI_SIMPLE_HAS_LP_STATE_REQ
      if (!pending_retrain_req)
        report_protocol_error($sformatf("Retrain state entered without observed retrain request old=0x%0h new=0x%0h",
                                        old_state, new_state));
      pending_retrain_req = 1'b0;
`else
      `uvm_info("RDI_SIMPLE_MON_STATE",
                $sformatf("%s Retrain state observed old=0x%0h new=0x%0h; request check disabled because UCIE_RDI_SIMPLE_HAS_LP_STATE_REQ is not defined",
                          side_to_string(), old_state, new_state),
                UVM_LOW)
`endif
    end

    if (linkerror_state_valid && (new_state == linkerror_state_value)) begin
      `uvm_warning("RDI_SIMPLE_MON_STATE",
                   $sformatf("%s LinkError state observed old=0x%0h new=0x%0h time=%0t",
                             side_to_string(), old_state, new_state, $time))
    end
  endfunction

`ifdef UCIE_RDI_SIMPLE_HAS_ERROR_SIGNALS
  function void check_rdi_error_signals();
    check_error_edge("lp_linkerror", rdi_vif.lp_linkerror, last_lp_linkerror, 1'b1);
    check_error_edge("pl_error", rdi_vif.pl_error, last_pl_error, 1'b0);
    check_error_edge("pl_trainerror", rdi_vif.pl_trainerror, last_pl_trainerror, 1'b1);
    check_error_edge("pl_nferror", rdi_vif.pl_nferror, last_pl_nferror, 1'b0);
    check_error_edge("pl_cerror", rdi_vif.pl_cerror, last_pl_cerror, 1'b0);
  endfunction

  function void check_error_edge(string sig_name, bit sig_value, ref bit last_value, bit fatal_signal);
    if (sig_value && !last_value) begin
      error_signal_count++;
      if (fatal_signal && error_signal_fatal_is_error) begin
        report_protocol_error($sformatf("%s asserted", sig_name));
      end else begin
        `uvm_warning("RDI_SIMPLE_MON_ERRSIG",
                     $sformatf("%s %s asserted state=0x%0h inband=%0b time=%0t",
                               side_to_string(), sig_name, rdi_vif.pl_state_sts,
                               rdi_vif.pl_inband_pres, $time))
      end
    end
    last_value = sig_value;
  endfunction
`endif

`ifdef UCIE_RDI_SIMPLE_HAS_PM_STALL_SIGNALS
  function void check_pm_stall_handshakes();
    check_req_ack("wake", rdi_vif.lp_wake_req, rdi_vif.pl_wake_ack,
                  wake_pending, wake_timer);
    check_req_ack("clk", rdi_vif.pl_clk_req, rdi_vif.lp_clk_ack,
                  clk_pending, clk_timer);
    check_req_ack("stall", rdi_vif.pl_stallreq, rdi_vif.lp_stallack,
                  stall_pending, stall_timer);

    if (stall_pending &&
        ((rdi_vif.lp_valid && rdi_vif.lp_irdy && rdi_vif.pl_trdy) || rdi_vif.pl_valid)) begin
      `uvm_warning("RDI_SIMPLE_MON_STALL",
                   $sformatf("%s data transfer observed while stall handshake is pending time=%0t",
                             side_to_string(), $time))
    end
  endfunction

  function void check_req_ack(string name, bit req, bit ack, ref bit pending, ref int unsigned timer);
    if (req && !ack) begin
      if (!pending) begin
        pending = 1'b1;
        timer = 0;
        `uvm_info("RDI_SIMPLE_MON_CTRL",
                  $sformatf("%s %s request observed time=%0t",
                            side_to_string(), name, $time),
                  UVM_LOW)
      end else begin
        timer++;
        if ((rdi_ctrl_timeout_limit != 0) && (timer > rdi_ctrl_timeout_limit)) begin
          rdi_ctrl_timeout_count++;
          report_protocol_error($sformatf("%s request timeout limit=%0d", name,
                                          rdi_ctrl_timeout_limit));
          pending = 1'b0;
          timer = 0;
        end
      end
    end else if (pending && ack) begin
      `uvm_info("RDI_SIMPLE_MON_CTRL",
                $sformatf("%s %s ack observed latency_cycles=%0d time=%0t",
                          side_to_string(), name, timer, $time),
                UVM_LOW)
      pending = 1'b0;
      timer = 0;
    end else if (!req) begin
      pending = 1'b0;
      timer = 0;
    end
  endfunction
`endif

  function void check_tx_backpressure_stability();
    bit tx_attempt;
    bit tx_accept;

    tx_attempt = rdi_vif.lp_valid && rdi_vif.lp_irdy;
    tx_accept = tx_attempt && rdi_vif.pl_trdy;

    if (tx_hold_active) begin
      if (!tx_attempt) begin
        report_protocol_error($sformatf("TX dropped lp_valid/lp_irdy before pl_trdy after hold_start=%0t",
                                        tx_hold_start_time));
        tx_hold_active = 1'b0;
      end else if (rdi_vif.lp_data !== tx_hold_data) begin
        report_protocol_error($sformatf("TX lp_data changed while pl_trdy=0 after hold_start=%0t old=0x%0h new=0x%0h",
                                        tx_hold_start_time, tx_hold_data, rdi_vif.lp_data));
        tx_hold_data = rdi_vif.lp_data;
      end else if (tx_accept) begin
        tx_hold_active = 1'b0;
      end
    end else if (tx_attempt && !rdi_vif.pl_trdy) begin
      tx_hold_active = 1'b1;
      tx_hold_data = rdi_vif.lp_data;
      tx_hold_start_time = $time;
    end
  endfunction

  function void report_protocol_error(string msg);
    protocol_error_count++;
    `uvm_error("RDI_SIMPLE_MON_SVA",
               $sformatf("%s %s state=0x%0h inband=%0b time=%0t",
                         side_to_string(), msg, rdi_vif.pl_state_sts,
                         rdi_vif.pl_inband_pres, $time))
  endfunction

  function ucie_rdi_simple_item make_item(ucie_rdi_simple_kind_e kind);
    ucie_rdi_simple_item item;

    item = ucie_rdi_simple_item::type_id::create("rdi_item");
    item.side = side;
    item.kind = kind;
    item.sample_time = $time;

    item.pl_state_sts = rdi_vif.pl_state_sts;
    item.pl_inband_pres = rdi_vif.pl_inband_pres;

    return item;
  endfunction

  function string side_to_string();
    case (side)
      UCIE_RDI_SIMPLE_US: return "US";
      UCIE_RDI_SIMPLE_DS: return "DS";
      default:            return "UNKNOWN";
    endcase
  endfunction

  function void log_item(ucie_rdi_simple_item item);
    if (log_each_item) begin
      `uvm_info("RDI_SIMPLE_MON",
                $sformatf("%s captured %s", side_to_string(),
                          item.convert2string()),
                UVM_MEDIUM)
    end
  endfunction

  function void log_sample(string direction, int unsigned sample_index, ucie_rdi_simple_item item);
    if (log_sample_values) begin
      `uvm_info("RDI_SIMPLE_MON_SAMPLE",
                $sformatf("side=%s dir=%s sample_index=%0d time=%0t state=0x%0h inband=%0b data=0x%0h",
                          side_to_string(), direction, sample_index,
                          item.sample_time, item.pl_state_sts,
                          item.pl_inband_pres, item.data),
                UVM_LOW)
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("RDI_SIMPLE_MON",
              $sformatf("%s tx_sample_count=%0d rx_sample_count=%0d state_transition_count=%0d error_signal_count=%0d rdi_ctrl_timeout_count=%0d protocol_error_count=%0d",
                        side_to_string(), tx_sample_count, rx_sample_count,
                        state_transition_count, error_signal_count,
                        rdi_ctrl_timeout_count, protocol_error_count),
              UVM_LOW)
  endfunction
endclass

`endif
