`ifndef UCIE_RDI_SIMPLE_SCB_SVH
`define UCIE_RDI_SIMPLE_SCB_SVH

`ifndef UCIE_RDI_SIMPLE_DATA_BITS
`define UCIE_RDI_SIMPLE_DATA_BITS 2048
`endif

typedef enum int {
  UCIE_RDI_SIMPLE_US = 0,
  UCIE_RDI_SIMPLE_DS = 1
} ucie_rdi_simple_side_e;

typedef enum int {
  UCIE_RDI_SIMPLE_MAINBAND_TX = 0,
  UCIE_RDI_SIMPLE_MAINBAND_RX = 1
} ucie_rdi_simple_kind_e;

class ucie_rdi_simple_item extends uvm_object;
  `uvm_object_utils(ucie_rdi_simple_item)

  ucie_rdi_simple_side_e side;
  ucie_rdi_simple_kind_e kind;
  time                   sample_time;

  bit [`UCIE_RDI_SIMPLE_DATA_BITS-1:0] data;
  bit [3:0]                            pl_state_sts;
  bit                                  pl_inband_pres;

  function new(string name = "ucie_rdi_simple_item");
    super.new(name);
  endfunction

  function string side_name();
    case (side)
      UCIE_RDI_SIMPLE_US: return "US";
      UCIE_RDI_SIMPLE_DS: return "DS";
      default:            return "UNKNOWN";
    endcase
  endfunction

  function string kind_name();
    case (kind)
      UCIE_RDI_SIMPLE_MAINBAND_TX: return "MAINBAND_TX";
      UCIE_RDI_SIMPLE_MAINBAND_RX: return "MAINBAND_RX";
      default:                     return "UNKNOWN";
    endcase
  endfunction

  function string convert2string();
    return $sformatf("side=%s kind=%s time=%0t data=0x%0h state=0x%0h inband=%0b",
                     side_name(), kind_name(), sample_time, data,
                     pl_state_sts, pl_inband_pres);
  endfunction
endclass

`uvm_analysis_imp_decl(_rdi_simple_us)
`uvm_analysis_imp_decl(_rdi_simple_ds)

class ucie_rdi_simple_scb extends uvm_scoreboard;
  `uvm_component_utils(ucie_rdi_simple_scb)

  uvm_analysis_imp_rdi_simple_us #(ucie_rdi_simple_item, ucie_rdi_simple_scb) us_export;
  uvm_analysis_imp_rdi_simple_ds #(ucie_rdi_simple_item, ucie_rdi_simple_scb) ds_export;

  ucie_rdi_simple_item us_tx_q[$];
  ucie_rdi_simple_item ds_rx_q[$];
  ucie_rdi_simple_item ds_tx_q[$];
  ucie_rdi_simple_item us_rx_q[$];

  int unsigned us_tx_count;
  int unsigned ds_rx_count;
  int unsigned ds_tx_count;
  int unsigned us_rx_count;
  int unsigned mainband_compare_count;
  int unsigned mismatch_count;

  bit fail_on_mismatch = 1'b1;

  function new(string name = "ucie_rdi_simple_scb", uvm_component parent = null);
    super.new(name, parent);
    us_export = new("us_export", this);
    ds_export = new("ds_export", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(bit)::get(this, "", "fail_on_mismatch", fail_on_mismatch));
  endfunction

  function void write_rdi_simple_us(ucie_rdi_simple_item item);
    route_item(item, UCIE_RDI_SIMPLE_US);
  endfunction

  function void write_rdi_simple_ds(ucie_rdi_simple_item item);
    route_item(item, UCIE_RDI_SIMPLE_DS);
  endfunction

  function void route_item(ucie_rdi_simple_item item, ucie_rdi_simple_side_e source);
    case (item.kind)
      UCIE_RDI_SIMPLE_MAINBAND_TX: begin
        if (source == UCIE_RDI_SIMPLE_US) begin
          us_tx_count++;
          us_tx_q.push_back(item);
        end else begin
          ds_tx_count++;
          ds_tx_q.push_back(item);
        end
      end

      UCIE_RDI_SIMPLE_MAINBAND_RX: begin
        if (source == UCIE_RDI_SIMPLE_US) begin
          us_rx_count++;
          us_rx_q.push_back(item);
        end else begin
          ds_rx_count++;
          ds_rx_q.push_back(item);
        end
      end
    endcase

    drain_queues();
  endfunction

  function void drain_queues();
    ucie_rdi_simple_item exp;
    ucie_rdi_simple_item got;

    while ((us_tx_q.size() != 0) && (ds_rx_q.size() != 0)) begin
      exp = us_tx_q.pop_front();
      got = ds_rx_q.pop_front();
      compare_mainband("US_TX_to_DS_RX", exp, got);
    end

    while ((ds_tx_q.size() != 0) && (us_rx_q.size() != 0)) begin
      exp = ds_tx_q.pop_front();
      got = us_rx_q.pop_front();
      compare_mainband("DS_TX_to_US_RX", exp, got);
    end
  endfunction

  function void compare_mainband(string path, ucie_rdi_simple_item exp, ucie_rdi_simple_item got);
    mainband_compare_count++;

    if (exp.data !== got.data)
      report_mismatch($sformatf("%s data mismatch", path), exp, got);
  endfunction

  function void report_mismatch(string msg, ucie_rdi_simple_item exp, ucie_rdi_simple_item got);
    mismatch_count++;
    if (fail_on_mismatch) begin
      `uvm_error("RDI_SIMPLE_SCB",
                 $sformatf("%s exp={%s} got={%s}",
                           msg, exp.convert2string(), got.convert2string()))
    end else begin
      `uvm_warning("RDI_SIMPLE_SCB",
                   $sformatf("%s exp={%s} got={%s}",
                             msg, exp.convert2string(), got.convert2string()))
    end
  endfunction

  function void report_leftover(string qname, int unsigned count);
    if (count != 0) begin
      mismatch_count += count;
      `uvm_error("RDI_SIMPLE_SCB",
                 $sformatf("%s has %0d unmatched item(s)", qname, count))
    end
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    drain_queues();

    report_leftover("us_tx_q", us_tx_q.size());
    report_leftover("ds_rx_q", ds_rx_q.size());
    report_leftover("ds_tx_q", ds_tx_q.size());
    report_leftover("us_rx_q", us_rx_q.size());
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("RDI_SIMPLE_SCB",
              $sformatf("us_tx_count=%0d ds_rx_count=%0d ds_tx_count=%0d us_rx_count=%0d mainband_compare_count=%0d mismatch_count=%0d",
                        us_tx_count, ds_rx_count, ds_tx_count, us_rx_count,
                        mainband_compare_count, mismatch_count),
              UVM_LOW)
  endfunction
endclass

`endif
