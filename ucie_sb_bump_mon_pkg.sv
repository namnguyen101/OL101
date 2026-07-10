package ucie_sb_bump_mon_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `uvm_analysis_imp_decl(_us_tx)
  `uvm_analysis_imp_decl(_us_rx)
  `uvm_analysis_imp_decl(_ds_tx)
  `uvm_analysis_imp_decl(_ds_rx)

  localparam int UCIE_SB_BUMP_WORD_BITS = 64;
  localparam int UCIE_SB_BUMP_LTSM_ASCII_BYTES = 32;

  localparam logic [4:0] UCIE_SB_OP_32B_MEM_RD       = 5'b00000;
  localparam logic [4:0] UCIE_SB_OP_32B_MEM_WR       = 5'b00001;
  localparam logic [4:0] UCIE_SB_OP_32B_DMS_RD       = 5'b00010;
  localparam logic [4:0] UCIE_SB_OP_32B_DMS_WR       = 5'b00011;
  localparam logic [4:0] UCIE_SB_OP_32B_CFG_RD       = 5'b00100;
  localparam logic [4:0] UCIE_SB_OP_32B_CFG_WR       = 5'b00101;
  localparam logic [4:0] UCIE_SB_OP_64B_MEM_RD       = 5'b01000;
  localparam logic [4:0] UCIE_SB_OP_64B_MEM_WR       = 5'b01001;
  localparam logic [4:0] UCIE_SB_OP_64B_DMS_RD       = 5'b01010;
  localparam logic [4:0] UCIE_SB_OP_64B_DMS_WR       = 5'b01011;
  localparam logic [4:0] UCIE_SB_OP_64B_CFG_RD       = 5'b01100;
  localparam logic [4:0] UCIE_SB_OP_64B_CFG_WR       = 5'b01101;
  localparam logic [4:0] UCIE_SB_OP_CPL_NO_DATA      = 5'b10000;
  localparam logic [4:0] UCIE_SB_OP_CPL_32B_DATA     = 5'b10001;
  localparam logic [4:0] UCIE_SB_OP_MSG_NO_DATA      = 5'b10010;
  localparam logic [4:0] UCIE_SB_OP_MPM_NO_DATA      = 5'b10111;
  localparam logic [4:0] UCIE_SB_OP_MPM_DATA         = 5'b11000;
  localparam logic [4:0] UCIE_SB_OP_CPL_64B_DATA     = 5'b11001;
  localparam logic [4:0] UCIE_SB_OP_MSG_64B_DATA     = 5'b11011;

  localparam logic [7:0] UCIE_SB_MSG_SBINIT_OOR      = 8'h91;
  localparam logic [7:0] UCIE_SB_MSG_SBINIT_REQ      = 8'h95;
  localparam logic [7:0] UCIE_SB_MSG_SBINIT_RSP      = 8'h9a;
  localparam logic [7:0] UCIE_SB_MSG_MBINIT_REQ      = 8'ha5;
  localparam logic [7:0] UCIE_SB_MSG_MBINIT_RSP      = 8'haa;
  localparam logic [7:0] UCIE_SBSC_SBINIT_OOR        = 8'h00;
  localparam logic [7:0] UCIE_SBSC_SBINIT_DONE       = 8'h01;
  localparam logic [7:0] UCIE_SBSC_MBINIT_PARAM_SBFE = 8'h01;

  typedef enum int unsigned {
    UCIE_SB_BUMP_US = 0,
    UCIE_SB_BUMP_DS = 1
  } ucie_sb_bump_side_e;

  typedef enum int unsigned {
    UCIE_SB_BUMP_TX = 0,
    UCIE_SB_BUMP_RX = 1
  } ucie_sb_bump_dir_e;

  typedef enum int unsigned {
    UCIE_SB_LANE_DATASB_CKSB       = 0,
    UCIE_SB_LANE_DATASB_CKSBRD     = 1,
    UCIE_SB_LANE_DATASBRD_CKSB     = 2,
    UCIE_SB_LANE_DATASBRD_CKSBRD   = 3
  } ucie_sb_bump_lane_e;

  typedef enum int unsigned {
    UCIE_SB_OBS_PACKET = 0,
    UCIE_SB_OBS_SBINIT_PATTERN = 1
  } ucie_sb_bump_obs_kind_e;

  function automatic string ucie_sb_bump_side_name(ucie_sb_bump_side_e side);
    return (side == UCIE_SB_BUMP_US) ? "US" : "DS";
  endfunction

  function automatic string ucie_sb_bump_dir_name(ucie_sb_bump_dir_e dir);
    return (dir == UCIE_SB_BUMP_TX) ? "TX" : "RX";
  endfunction

  function automatic string ucie_sb_bump_lane_name(ucie_sb_bump_lane_e lane);
    case (lane)
      UCIE_SB_LANE_DATASB_CKSB:     return "DATASB/CKSB";
      UCIE_SB_LANE_DATASB_CKSBRD:   return "DATASB/CKSBRD";
      UCIE_SB_LANE_DATASBRD_CKSB:   return "DATASBRD/CKSB";
      UCIE_SB_LANE_DATASBRD_CKSBRD: return "DATASBRD/CKSBRD";
      default:                      return "UNKNOWN";
    endcase
  endfunction

  function automatic logic [63:0] ucie_sb_get_field(
    input logic [63:0] raw,
    input int          lsb,
    input int          width
  );
    logic [63:0] mask;
    if (lsb < 0 || width <= 0 || lsb >= 64) begin
      return '0;
    end
    if (width >= 64) begin
      mask = '1;
    end else begin
      mask = (64'h1 << width) - 64'h1;
    end
    return (raw >> lsb) & mask;
  endfunction

  function automatic bit ucie_sb_is_opcode_with_data(input logic [4:0] opcode);
    case (opcode)
      UCIE_SB_OP_32B_MEM_WR,
      UCIE_SB_OP_32B_DMS_WR,
      UCIE_SB_OP_32B_CFG_WR,
      UCIE_SB_OP_64B_MEM_WR,
      UCIE_SB_OP_64B_DMS_WR,
      UCIE_SB_OP_64B_CFG_WR,
      UCIE_SB_OP_CPL_32B_DATA,
      UCIE_SB_OP_MPM_DATA,
      UCIE_SB_OP_CPL_64B_DATA,
      UCIE_SB_OP_MSG_64B_DATA: return 1'b1;
      default:                 return 1'b0;
    endcase
  endfunction

  class ucie_sb_bump_cfg extends uvm_object;
    `uvm_object_utils(ucie_sb_bump_cfg)

    ucie_sb_bump_side_e side = UCIE_SB_BUMP_US;
    int unsigned        module_id = 0;
    bit                 is_advanced_pkg = 0;
    bit                 enable_redundant = 0;
    bit                 reset_active_high = 1;
    bit                 sample_on_negedge = 1;
    bit                 gap_check_en = 1;
    bit                 pmo_en = 0;
    bit                 pmo_auto_detect_en = 1;
    bit                 strict_sbinit_starts_with_one = 0;
    bit                 lane_check_en = 1;
    bit                 x_check_en = 1;
    bit                 parity_check_en = 1;
    bit                 data_parity_check_en = 0;
    bit                 log_each_item = 0;

    realtime            ui_time_ns = 1.25;
    realtime            min_gap_ui = 32.0;
    int unsigned        max_data_qwords = 8;
    int unsigned        default_mpm_data_qwords = 1;

    int opcode_lsb = 0;
    int srcid_lsb = 5;
    int dstid_lsb = 8;
    int msgcode_lsb = 11;
    int msgsubcode_lsb = 19;
    int msginfo_lsb = 27;
    int credit_return_lsb = 43;
    int cp_lsb = 44;
    int dp_lsb = -1;
    int tag_lsb = -1;
    int addr_lsb = -1;
    int be_lsb = -1;
    int mpm_length_lsb = -1;

    int opcode_width = 5;
    int srcid_width = 3;
    int dstid_width = 3;
    int msgcode_width = 8;
    int msgsubcode_width = 8;
    int msginfo_width = 16;
    int tag_width = 5;
    int addr_width = 24;
    int be_width = 8;
    int mpm_length_width = 4;

    function new(string name = "ucie_sb_bump_cfg");
      super.new(name);
    endfunction

    function ucie_sb_bump_cfg clone_cfg(string name = "ucie_sb_bump_cfg_clone");
      ucie_sb_bump_cfg c;
      c = ucie_sb_bump_cfg::type_id::create(name);
      c.copy(this);
      return c;
    endfunction
  endclass

  class ucie_sb_bump_item extends uvm_sequence_item;
    `uvm_object_utils(ucie_sb_bump_item)

    ucie_sb_bump_obs_kind_e kind;
    ucie_sb_bump_side_e     side;
    int unsigned            module_id;
    ucie_sb_bump_dir_e      dir;
    ucie_sb_bump_lane_e     lane;

    realtime                start_time_ns;
    realtime                end_time_ns;
    realtime                gap_ui_before;
    string                  ltsm_state;

    logic [63:0]            raw_header;
    logic [63:0]            data_q[$];

    bit                     has_data;
    bit                     xz_seen;
    bit                     gap_ok;
    bit                     cp_ok;
    bit                     dp_ok;
    bit                     lane_ok;
    int unsigned            sbinit_pattern_count;

    logic [4:0]             opcode;
    logic [2:0]             srcid;
    logic [2:0]             dstid;
    logic [7:0]             msgcode;
    logic [7:0]             msgsubcode;
    logic [15:0]            msginfo;
    logic                   credit_return;
    logic                   control_parity;
    logic                   data_parity;
    logic [4:0]             tag;
    logic [23:0]            addr;
    logic [7:0]             be;

    function new(string name = "ucie_sb_bump_item");
      super.new(name);
      gap_ok = 1'b1;
      cp_ok = 1'b1;
      dp_ok = 1'b1;
      lane_ok = 1'b1;
    endfunction

    function void do_copy(uvm_object rhs);
      ucie_sb_bump_item rhs_;
      super.do_copy(rhs);
      if (!$cast(rhs_, rhs)) begin
        `uvm_fatal("SB_BUMP_COPY", "do_copy cast failed")
      end
      kind = rhs_.kind;
      side = rhs_.side;
      module_id = rhs_.module_id;
      dir = rhs_.dir;
      lane = rhs_.lane;
      start_time_ns = rhs_.start_time_ns;
      end_time_ns = rhs_.end_time_ns;
      gap_ui_before = rhs_.gap_ui_before;
      ltsm_state = rhs_.ltsm_state;
      raw_header = rhs_.raw_header;
      data_q = rhs_.data_q;
      has_data = rhs_.has_data;
      xz_seen = rhs_.xz_seen;
      gap_ok = rhs_.gap_ok;
      cp_ok = rhs_.cp_ok;
      dp_ok = rhs_.dp_ok;
      lane_ok = rhs_.lane_ok;
      sbinit_pattern_count = rhs_.sbinit_pattern_count;
      opcode = rhs_.opcode;
      srcid = rhs_.srcid;
      dstid = rhs_.dstid;
      msgcode = rhs_.msgcode;
      msgsubcode = rhs_.msgsubcode;
      msginfo = rhs_.msginfo;
      credit_return = rhs_.credit_return;
      control_parity = rhs_.control_parity;
      data_parity = rhs_.data_parity;
      tag = rhs_.tag;
      addr = rhs_.addr;
      be = rhs_.be;
    endfunction

    function string convert2string();
      string data_s;
      data_s = "";
      foreach (data_q[i]) begin
        data_s = {data_s, $sformatf(" data[%0d]=0x%016h", i, data_q[i])};
      end
      return $sformatf(
        "%s[%0d] %s %s kind=%0d ltsm=%s t=%0.3f gap_ui=%0.2f raw=0x%016h op=0x%02h src=%0d dst=%0d msg=0x%02h sub=0x%02h info=0x%04h cp_ok=%0b dp_ok=%0b lane_ok=%0b xz=%0b%s",
        ucie_sb_bump_side_name(side), module_id, ucie_sb_bump_dir_name(dir),
        ucie_sb_bump_lane_name(lane), kind, ltsm_state, start_time_ns,
        gap_ui_before, raw_header, opcode, srcid, dstid, msgcode, msgsubcode,
        msginfo, cp_ok, dp_ok, lane_ok, xz_seen, data_s
      );
    endfunction
  endclass

  class ucie_sb_bump_monitor extends uvm_component;
    `uvm_component_utils(ucie_sb_bump_monitor)

    ucie_sb_bump_cfg cfg;
    virtual ucie_sb_bump_probe_if.mon vif;

    uvm_analysis_port #(ucie_sb_bump_item) tx_ap;
    uvm_analysis_port #(ucie_sb_bump_item) rx_ap;

    bit functional_lane_known;
    ucie_sb_bump_lane_e functional_lane;
    int unsigned pattern_count[ucie_sb_bump_dir_e][ucie_sb_bump_lane_e];

    function new(string name, uvm_component parent);
      super.new(name, parent);
      tx_ap = new("tx_ap", this);
      rx_ap = new("rx_ap", this);
      functional_lane = UCIE_SB_LANE_DATASB_CKSB;
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(ucie_sb_bump_cfg)::get(this, "", "cfg", cfg)) begin
        cfg = ucie_sb_bump_cfg::type_id::create("cfg");
      end
      if (!uvm_config_db#(virtual ucie_sb_bump_probe_if.mon)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NO_SB_BUMP_VIF", $sformatf("%s missing ucie_sb_bump_probe_if.mon", get_full_name()))
      end
    endfunction

    task run_phase(uvm_phase phase);
      fork
        collect_stream(UCIE_SB_BUMP_TX, UCIE_SB_LANE_DATASB_CKSB);
        collect_stream(UCIE_SB_BUMP_RX, UCIE_SB_LANE_DATASB_CKSB);
        begin
          if (cfg.enable_redundant || cfg.is_advanced_pkg) begin
            fork
              collect_stream(UCIE_SB_BUMP_TX, UCIE_SB_LANE_DATASB_CKSBRD);
              collect_stream(UCIE_SB_BUMP_TX, UCIE_SB_LANE_DATASBRD_CKSB);
              collect_stream(UCIE_SB_BUMP_TX, UCIE_SB_LANE_DATASBRD_CKSBRD);
              collect_stream(UCIE_SB_BUMP_RX, UCIE_SB_LANE_DATASB_CKSBRD);
              collect_stream(UCIE_SB_BUMP_RX, UCIE_SB_LANE_DATASBRD_CKSB);
              collect_stream(UCIE_SB_BUMP_RX, UCIE_SB_LANE_DATASBRD_CKSBRD);
            join
          end
        end
      join
    endtask

    function bit reset_asserted();
      if (cfg.reset_active_high) begin
        return (vif.reset === 1'b1);
      end
      return (vif.reset === 1'b0);
    endfunction

    task wait_reset_deasserted();
      while (reset_asserted()) begin
        @(vif.reset);
      end
    endtask

    task automatic wait_sample_edge(
      input  ucie_sb_bump_dir_e  dir,
      input  ucie_sb_bump_lane_e lane,
      output logic               data
    );
      if (dir == UCIE_SB_BUMP_TX) begin
        case (lane)
          UCIE_SB_LANE_DATASB_CKSB: begin
            if (cfg.sample_on_negedge) @(negedge vif.TXCKSB); else @(posedge vif.TXCKSB);
            data = vif.TXDATASB;
          end
          UCIE_SB_LANE_DATASB_CKSBRD: begin
            if (cfg.sample_on_negedge) @(negedge vif.TXCKSBRD); else @(posedge vif.TXCKSBRD);
            data = vif.TXDATASB;
          end
          UCIE_SB_LANE_DATASBRD_CKSB: begin
            if (cfg.sample_on_negedge) @(negedge vif.TXCKSB); else @(posedge vif.TXCKSB);
            data = vif.TXDATASBRD;
          end
          default: begin
            if (cfg.sample_on_negedge) @(negedge vif.TXCKSBRD); else @(posedge vif.TXCKSBRD);
            data = vif.TXDATASBRD;
          end
        endcase
      end else begin
        case (lane)
          UCIE_SB_LANE_DATASB_CKSB: begin
            if (cfg.sample_on_negedge) @(negedge vif.RXCKSB); else @(posedge vif.RXCKSB);
            data = vif.RXDATASB;
          end
          UCIE_SB_LANE_DATASB_CKSBRD: begin
            if (cfg.sample_on_negedge) @(negedge vif.RXCKSBRD); else @(posedge vif.RXCKSBRD);
            data = vif.RXDATASB;
          end
          UCIE_SB_LANE_DATASBRD_CKSB: begin
            if (cfg.sample_on_negedge) @(negedge vif.RXCKSB); else @(posedge vif.RXCKSB);
            data = vif.RXDATASBRD;
          end
          default: begin
            if (cfg.sample_on_negedge) @(negedge vif.RXCKSBRD); else @(posedge vif.RXCKSBRD);
            data = vif.RXDATASBRD;
          end
        endcase
      end
    endtask

    task automatic capture_word(
      input  ucie_sb_bump_dir_e  dir,
      input  ucie_sb_bump_lane_e lane,
      output logic [63:0]        raw,
      output realtime            start_time_ns,
      output realtime            end_time_ns,
      output bit                 xz_seen,
      output bit                 aborted
    );
      logic sampled;
      raw = '0;
      start_time_ns = 0.0;
      end_time_ns = 0.0;
      xz_seen = 1'b0;
      aborted = 1'b0;
      for (int i = 0; i < UCIE_SB_BUMP_WORD_BITS; i++) begin
        wait_sample_edge(dir, lane, sampled);
        if (reset_asserted()) begin
          aborted = 1'b1;
          return;
        end
        if (i == 0) start_time_ns = $realtime;
        if ($isunknown(sampled)) begin
          xz_seen = 1'b1;
          raw[i] = 1'b0;
        end else begin
          raw[i] = sampled;
        end
      end
      end_time_ns = $realtime;
    endtask

    task automatic collect_stream(
      input ucie_sb_bump_dir_e  dir,
      input ucie_sb_bump_lane_e lane
    );
      logic [63:0] raw;
      logic [63:0] data_raw;
      realtime start_time_ns;
      realtime end_time_ns;
      realtime prev_end_time_ns;
      realtime data_start_time_ns;
      realtime data_end_time_ns;
      bit xz_seen;
      bit data_xz_seen;
      bit aborted;
      bit have_prev_word;
      realtime gap_ui;

      have_prev_word = 1'b0;
      prev_end_time_ns = 0.0;

      forever begin
        wait_reset_deasserted();
        capture_word(dir, lane, raw, start_time_ns, end_time_ns, xz_seen, aborted);
        if (aborted) begin
          have_prev_word = 1'b0;
          prev_end_time_ns = 0.0;
          continue;
        end

        gap_ui = have_prev_word ? ((start_time_ns - prev_end_time_ns) / cfg.ui_time_ns) : 999999.0;

        if (is_sbinit_pattern(raw)) begin
          pattern_count[dir][lane]++;
          publish_pattern(dir, lane, raw, start_time_ns, end_time_ns, gap_ui, xz_seen);
          prev_end_time_ns = end_time_ns;
          have_prev_word = 1'b1;
          continue;
        end

        pattern_count[dir][lane] = 0;
        begin
          ucie_sb_bump_item item;
          int unsigned data_words;
          item = ucie_sb_bump_item::type_id::create("item");
          item.kind = UCIE_SB_OBS_PACKET;
          item.side = cfg.side;
          item.module_id = cfg.module_id;
          item.dir = dir;
          item.lane = lane;
          item.start_time_ns = start_time_ns;
          item.end_time_ns = end_time_ns;
          item.gap_ui_before = gap_ui;
          item.ltsm_state = get_ltsm_string();
          item.raw_header = raw;
          item.xz_seen = xz_seen;
          item.gap_ok = !cfg.gap_check_en || cfg.pmo_en || !have_prev_word || (gap_ui >= cfg.min_gap_ui);
          decode_item(item);
          item.lane_ok = lane_is_allowed(lane);

          data_words = expected_data_qwords(item);
          for (int unsigned i = 0; i < data_words; i++) begin
            capture_word(dir, lane, data_raw, data_start_time_ns, data_end_time_ns, data_xz_seen, aborted);
            if (aborted) break;
            item.has_data = 1'b1;
            item.data_q.push_back(data_raw);
            item.xz_seen |= data_xz_seen;
            item.dp_ok &= check_data_parity(data_raw, item.data_parity);
            if (cfg.gap_check_en && !cfg.pmo_en) begin
              realtime data_gap_ui;
              data_gap_ui = (data_start_time_ns - item.end_time_ns) / cfg.ui_time_ns;
              if (data_gap_ui < cfg.min_gap_ui) item.gap_ok = 1'b0;
            end
            item.end_time_ns = data_end_time_ns;
          end

          update_learned_modes(item);
          publish_packet(item);
          prev_end_time_ns = item.end_time_ns;
          have_prev_word = 1'b1;
        end
      end
    endtask

    function bit is_sbinit_pattern(input logic [63:0] raw);
      if (cfg.strict_sbinit_starts_with_one) begin
        return (raw === 64'h5555_5555_5555_5555);
      end
      return (raw === 64'h5555_5555_5555_5555) ||
             (raw === 64'haaaa_aaaa_aaaa_aaaa);
    endfunction

    function bit lane_is_allowed(input ucie_sb_bump_lane_e lane);
      if (!(cfg.is_advanced_pkg || cfg.enable_redundant)) begin
        return (lane == UCIE_SB_LANE_DATASB_CKSB);
      end
      if (!cfg.lane_check_en || !functional_lane_known) begin
        return 1'b1;
      end
      return (lane == functional_lane);
    endfunction

    function string get_ltsm_string();
      string s;
      s = "";
      for (int i = UCIE_SB_BUMP_LTSM_ASCII_BYTES-1; i >= 0; i--) begin
        byte c;
        c = vif.debug_ascii_phy_ltsm_state[i*8 +: 8];
        if (c != 8'h00) s = {s, c};
      end
      if (s.len() == 0) s = "UNKNOWN";
      return s;
    endfunction

    function void decode_item(ref ucie_sb_bump_item item);
      logic [63:0] field;
      field = ucie_sb_get_field(item.raw_header, cfg.opcode_lsb, cfg.opcode_width);
      item.opcode = field[4:0];
      field = ucie_sb_get_field(item.raw_header, cfg.srcid_lsb, cfg.srcid_width);
      item.srcid = field[2:0];
      field = ucie_sb_get_field(item.raw_header, cfg.dstid_lsb, cfg.dstid_width);
      item.dstid = field[2:0];
      field = ucie_sb_get_field(item.raw_header, cfg.msgcode_lsb, cfg.msgcode_width);
      item.msgcode = field[7:0];
      field = ucie_sb_get_field(item.raw_header, cfg.msgsubcode_lsb, cfg.msgsubcode_width);
      item.msgsubcode = field[7:0];
      field = ucie_sb_get_field(item.raw_header, cfg.msginfo_lsb, cfg.msginfo_width);
      item.msginfo = field[15:0];
      field = ucie_sb_get_field(item.raw_header, cfg.credit_return_lsb, 1);
      item.credit_return = field[0];
      field = ucie_sb_get_field(item.raw_header, cfg.cp_lsb, 1);
      item.control_parity = field[0];
      field = ucie_sb_get_field(item.raw_header, cfg.dp_lsb, 1);
      item.data_parity = field[0];
      field = ucie_sb_get_field(item.raw_header, cfg.tag_lsb, cfg.tag_width);
      item.tag = field[4:0];
      field = ucie_sb_get_field(item.raw_header, cfg.addr_lsb, cfg.addr_width);
      item.addr = field[23:0];
      field = ucie_sb_get_field(item.raw_header, cfg.be_lsb, cfg.be_width);
      item.be = field[7:0];
      item.cp_ok = check_control_parity(item.raw_header);
      item.dp_ok = 1'b1;
    endfunction

    function bit check_control_parity(input logic [63:0] raw);
      logic [63:0] masked;
      if (!cfg.parity_check_en || cfg.cp_lsb < 0) begin
        return 1'b1;
      end
      masked = raw;
      masked[cfg.cp_lsb] = 1'b0;
      if (cfg.dp_lsb >= 0) masked[cfg.dp_lsb] = 1'b0;
      return (raw[cfg.cp_lsb] === (^masked));
    endfunction

    function bit check_data_parity(input logic [63:0] data, input logic dp);
      if (!cfg.data_parity_check_en || cfg.dp_lsb < 0) begin
        return 1'b1;
      end
      return (dp === (^data));
    endfunction

    function int unsigned expected_data_qwords(input ucie_sb_bump_item item);
      int unsigned qwords;
      qwords = 0;
      if (ucie_sb_is_opcode_with_data(item.opcode)) begin
        qwords = 1;
        if (item.opcode == UCIE_SB_OP_MPM_DATA) begin
          if (cfg.mpm_length_lsb >= 0) begin
            qwords = ucie_sb_get_field(item.raw_header, cfg.mpm_length_lsb,
                                       cfg.mpm_length_width) + 1;
          end else begin
            qwords = cfg.default_mpm_data_qwords;
          end
        end
      end
      if (qwords > cfg.max_data_qwords) qwords = cfg.max_data_qwords;
      return qwords;
    endfunction

    function ucie_sb_bump_lane_e lane_from_result(input logic [3:0] result);
      if (result[0]) return UCIE_SB_LANE_DATASB_CKSB;
      if (result[1]) return UCIE_SB_LANE_DATASB_CKSBRD;
      if (result[2]) return UCIE_SB_LANE_DATASBRD_CKSB;
      if (result[3]) return UCIE_SB_LANE_DATASBRD_CKSBRD;
      return UCIE_SB_LANE_DATASB_CKSB;
    endfunction

    function void update_learned_modes(ucie_sb_bump_item item);
      if (item.kind != UCIE_SB_OBS_PACKET) return;

      if ((cfg.is_advanced_pkg || cfg.enable_redundant) &&
          item.msgcode == UCIE_SB_MSG_SBINIT_OOR &&
          item.msgsubcode == UCIE_SBSC_SBINIT_OOR &&
          item.msginfo[3:0] != 4'h0) begin
        functional_lane = lane_from_result(item.msginfo[3:0]);
        functional_lane_known = 1'b1;
        `uvm_info("SB_BUMP_LANE",
                  $sformatf("%s[%0d] learned functional sideband %s from Result[3:0]=0x%0h",
                            ucie_sb_bump_side_name(cfg.side), cfg.module_id,
                            ucie_sb_bump_lane_name(functional_lane), item.msginfo[3:0]),
                  UVM_LOW)
      end

      if (cfg.pmo_auto_detect_en &&
          item.msgcode == UCIE_SB_MSG_MBINIT_RSP &&
          item.msgsubcode == UCIE_SBSC_MBINIT_PARAM_SBFE &&
          item.msginfo[1]) begin
        cfg.pmo_en = 1'b1;
        `uvm_info("SB_BUMP_PMO",
                  $sformatf("%s[%0d] learned Sideband PMO enabled",
                            ucie_sb_bump_side_name(cfg.side), cfg.module_id),
                  UVM_LOW)
      end
    endfunction

    function void publish_pattern(
      input ucie_sb_bump_dir_e  dir,
      input ucie_sb_bump_lane_e lane,
      input logic [63:0]        raw,
      input realtime            start_time_ns,
      input realtime            end_time_ns,
      input realtime            gap_ui,
      input bit                 xz_seen
    );
      ucie_sb_bump_item item;
      item = ucie_sb_bump_item::type_id::create("sbinit_pattern");
      item.kind = UCIE_SB_OBS_SBINIT_PATTERN;
      item.side = cfg.side;
      item.module_id = cfg.module_id;
      item.dir = dir;
      item.lane = lane;
      item.raw_header = raw;
      item.start_time_ns = start_time_ns;
      item.end_time_ns = end_time_ns;
      item.gap_ui_before = gap_ui;
      item.ltsm_state = get_ltsm_string();
      item.xz_seen = xz_seen;
      item.sbinit_pattern_count = pattern_count[dir][lane];
      item.lane_ok = lane_is_allowed(lane);
      if (cfg.log_each_item) begin
        `uvm_info("SB_BUMP_PATTERN", item.convert2string(), UVM_MEDIUM)
      end
      if (dir == UCIE_SB_BUMP_TX) tx_ap.write(item);
      else rx_ap.write(item);
    endfunction

    function void publish_packet(ucie_sb_bump_item item);
      if (cfg.x_check_en && item.xz_seen) begin
        `uvm_error("SB_BUMP_XZ", item.convert2string())
      end
      if (!item.gap_ok) begin
        `uvm_error("SB_BUMP_GAP", item.convert2string())
      end
      if (!item.cp_ok) begin
        `uvm_error("SB_BUMP_CP", item.convert2string())
      end
      if (!item.lane_ok) begin
        `uvm_error("SB_BUMP_LANE", item.convert2string())
      end
      if (cfg.log_each_item) begin
        `uvm_info("SB_BUMP_ITEM", item.convert2string(), UVM_MEDIUM)
      end
      if (item.dir == UCIE_SB_BUMP_TX) tx_ap.write(item);
      else rx_ap.write(item);
    endfunction
  endclass

  class ucie_sb_bump_scb_cfg extends uvm_object;
    `uvm_object_utils(ucie_sb_bump_scb_cfg)

    bit          compare_patterns = 0;
    bit          fail_on_mismatch = 1;
    bit          latency_check_en = 1;
    realtime     ui_time_ns = 1.25;
    realtime     min_latency_ui = 0.0;
    realtime     max_latency_ui = 2048.0;
    bit          log_each_compare = 0;

    function new(string name = "ucie_sb_bump_scb_cfg");
      super.new(name);
    endfunction
  endclass

  class ucie_sb_bump_scb extends uvm_component;
    `uvm_component_utils(ucie_sb_bump_scb)

    ucie_sb_bump_scb_cfg cfg;
    uvm_analysis_imp_us_tx #(ucie_sb_bump_item, ucie_sb_bump_scb) us_tx_export;
    uvm_analysis_imp_us_rx #(ucie_sb_bump_item, ucie_sb_bump_scb) us_rx_export;
    uvm_analysis_imp_ds_tx #(ucie_sb_bump_item, ucie_sb_bump_scb) ds_tx_export;
    uvm_analysis_imp_ds_rx #(ucie_sb_bump_item, ucie_sb_bump_scb) ds_rx_export;

    ucie_sb_bump_item us_tx_q[$];
    ucie_sb_bump_item us_rx_q[$];
    ucie_sb_bump_item ds_tx_q[$];
    ucie_sb_bump_item ds_rx_q[$];

    int unsigned compare_count;
    int unsigned error_count;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      us_tx_export = new("us_tx_export", this);
      us_rx_export = new("us_rx_export", this);
      ds_tx_export = new("ds_tx_export", this);
      ds_rx_export = new("ds_rx_export", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(ucie_sb_bump_scb_cfg)::get(this, "", "cfg", cfg)) begin
        cfg = ucie_sb_bump_scb_cfg::type_id::create("cfg");
      end
    endfunction

    function void write_us_tx(ucie_sb_bump_item item);
      push_item(us_tx_q, item);
      match_us_to_ds();
    endfunction

    function void write_us_rx(ucie_sb_bump_item item);
      push_item(us_rx_q, item);
      match_ds_to_us();
    endfunction

    function void write_ds_tx(ucie_sb_bump_item item);
      push_item(ds_tx_q, item);
      match_ds_to_us();
    endfunction

    function void write_ds_rx(ucie_sb_bump_item item);
      push_item(ds_rx_q, item);
      match_us_to_ds();
    endfunction

    function void push_item(ref ucie_sb_bump_item q[$], ucie_sb_bump_item item);
      ucie_sb_bump_item copy;
      if (!cfg.compare_patterns && item.kind != UCIE_SB_OBS_PACKET) return;
      $cast(copy, item.clone());
      q.push_back(copy);
    endfunction

    function void match_us_to_ds();
      while (us_tx_q.size() != 0 && ds_rx_q.size() != 0) begin
        compare_pair(us_tx_q.pop_front(), ds_rx_q.pop_front(), "US_TX_to_DS_RX");
      end
    endfunction

    function void match_ds_to_us();
      while (ds_tx_q.size() != 0 && us_rx_q.size() != 0) begin
        compare_pair(ds_tx_q.pop_front(), us_rx_q.pop_front(), "DS_TX_to_US_RX");
      end
    endfunction

    function void compare_pair(
      input ucie_sb_bump_item tx,
      input ucie_sb_bump_item rx,
      input string            path_name
    );
      bit mismatch;
      realtime latency_ui;
      mismatch = 1'b0;
      compare_count++;

      if (tx.raw_header !== rx.raw_header) mismatch = 1'b1;
      if (tx.data_q.size() != rx.data_q.size()) mismatch = 1'b1;
      foreach (tx.data_q[i]) begin
        if (i >= rx.data_q.size() || tx.data_q[i] !== rx.data_q[i]) mismatch = 1'b1;
      end

      latency_ui = (rx.start_time_ns - tx.start_time_ns) / cfg.ui_time_ns;
      if (cfg.latency_check_en &&
          (latency_ui < cfg.min_latency_ui || latency_ui > cfg.max_latency_ui)) begin
        mismatch = 1'b1;
        report_error("LATENCY", $sformatf("%s latency_ui=%0.2f tx={%s} rx={%s}",
                                          path_name, latency_ui,
                                          tx.convert2string(), rx.convert2string()));
      end

      if (mismatch) begin
        report_error("MISMATCH", $sformatf("%s tx={%s} rx={%s}",
                                           path_name, tx.convert2string(),
                                           rx.convert2string()));
      end else if (cfg.log_each_compare) begin
        `uvm_info("SB_BUMP_COMPARE",
                  $sformatf("%s PASS latency_ui=%0.2f raw=0x%016h",
                            path_name, latency_ui, tx.raw_header),
                  UVM_MEDIUM)
      end
    endfunction

    function void report_error(input string id, input string msg);
      error_count++;
      if (cfg.fail_on_mismatch) begin
        `uvm_error({"SB_BUMP_", id}, msg)
      end else begin
        `uvm_warning({"SB_BUMP_", id}, msg)
      end
    endfunction

    function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if (us_tx_q.size() != 0) report_error("MISSING_DS_RX", $sformatf("%0d unmatched US TX item(s)", us_tx_q.size()));
      if (ds_rx_q.size() != 0) report_error("UNEXPECTED_DS_RX", $sformatf("%0d unmatched DS RX item(s)", ds_rx_q.size()));
      if (ds_tx_q.size() != 0) report_error("MISSING_US_RX", $sformatf("%0d unmatched DS TX item(s)", ds_tx_q.size()));
      if (us_rx_q.size() != 0) report_error("UNEXPECTED_US_RX", $sformatf("%0d unmatched US RX item(s)", us_rx_q.size()));
    endfunction
  endclass

  class ucie_sb_bump_pair_env extends uvm_env;
    `uvm_component_utils(ucie_sb_bump_pair_env)

    ucie_sb_bump_monitor us_mon;
    ucie_sb_bump_monitor ds_mon;
    ucie_sb_bump_scb     scb;

    ucie_sb_bump_cfg     us_cfg;
    ucie_sb_bump_cfg     ds_cfg;
    ucie_sb_bump_scb_cfg scb_cfg;

    virtual ucie_sb_bump_probe_if.mon us_vif;
    virtual ucie_sb_bump_probe_if.mon ds_vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      if (!uvm_config_db#(virtual ucie_sb_bump_probe_if.mon)::get(this, "", "us_vif", us_vif)) begin
        `uvm_fatal("NO_US_SB_BUMP_VIF", $sformatf("%s missing us_vif", get_full_name()))
      end
      if (!uvm_config_db#(virtual ucie_sb_bump_probe_if.mon)::get(this, "", "ds_vif", ds_vif)) begin
        `uvm_fatal("NO_DS_SB_BUMP_VIF", $sformatf("%s missing ds_vif", get_full_name()))
      end

      if (!uvm_config_db#(ucie_sb_bump_cfg)::get(this, "", "us_cfg", us_cfg)) begin
        us_cfg = ucie_sb_bump_cfg::type_id::create("us_cfg");
      end
      if (!uvm_config_db#(ucie_sb_bump_cfg)::get(this, "", "ds_cfg", ds_cfg)) begin
        ds_cfg = ucie_sb_bump_cfg::type_id::create("ds_cfg");
      end
      if (!uvm_config_db#(ucie_sb_bump_scb_cfg)::get(this, "", "scb_cfg", scb_cfg)) begin
        scb_cfg = ucie_sb_bump_scb_cfg::type_id::create("scb_cfg");
      end

      us_cfg.side = UCIE_SB_BUMP_US;
      ds_cfg.side = UCIE_SB_BUMP_DS;

      uvm_config_db#(ucie_sb_bump_cfg)::set(this, "us_mon", "cfg", us_cfg);
      uvm_config_db#(ucie_sb_bump_cfg)::set(this, "ds_mon", "cfg", ds_cfg);
      uvm_config_db#(ucie_sb_bump_scb_cfg)::set(this, "scb", "cfg", scb_cfg);
      uvm_config_db#(virtual ucie_sb_bump_probe_if.mon)::set(this, "us_mon", "vif", us_vif);
      uvm_config_db#(virtual ucie_sb_bump_probe_if.mon)::set(this, "ds_mon", "vif", ds_vif);

      us_mon = ucie_sb_bump_monitor::type_id::create("us_mon", this);
      ds_mon = ucie_sb_bump_monitor::type_id::create("ds_mon", this);
      scb = ucie_sb_bump_scb::type_id::create("scb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      us_mon.tx_ap.connect(scb.us_tx_export);
      us_mon.rx_ap.connect(scb.us_rx_export);
      ds_mon.tx_ap.connect(scb.ds_tx_export);
      ds_mon.rx_ap.connect(scb.ds_rx_export);
    endfunction
  endclass
endpackage
