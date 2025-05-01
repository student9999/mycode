onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/ADDR_WIDTH
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/DATA_WIDTH
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/ID_WIDTH
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/BUFFER_DEPTH
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/BEAT_BYTES
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/BUFFER_WORDS
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/SIZE_CODE
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/clk
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/rst_n
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/s_axis_tdata
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/s_axis_tvalid
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/s_axis_tready
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/s_axis_tlast
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/total_length_field
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/m_axi_awid
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/m_axi_awaddr
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/m_axi_awlen
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/m_axi_awsize
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/m_axi_awburst
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/m_axi_awvalid
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/m_axi_awready
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/m_axi_wdata
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/m_axi_wstrb
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/m_axi_wlast
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/m_axi_wvalid
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/m_axi_wready
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/m_axi_bid
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/m_axi_bresp
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/m_axi_bvalid
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/m_axi_bready
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/base_addr
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/rx_state
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/tx_state
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/rx_wr_ptr
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/rx_packet_len
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/rx_byte_cnt
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/buffer0
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/buffer1
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/active_buf_sel
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/packet_ready
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/packet_len_saved
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/tx_buf_sel
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/tx_rd_ptr
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/tx_byte_cnt
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/tx_addr
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/tx_data_stage1
add wave -noupdate /axis_ipv4_to_axi4_writer_tb/dut/tx_data_stage2
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {346002 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 334
configure wave -valuecolwidth 242
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {1191400 ps}
