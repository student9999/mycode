onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/dut/ADDR_WIDTH
add wave -noupdate /tb/dut/DATA_WIDTH
add wave -noupdate /tb/dut/BUFFER_DEPTH
add wave -noupdate /tb/dut/BEAT_BYTES
add wave -noupdate /tb/dut/BUFFER_WORDS
add wave -noupdate /tb/dut/clk
add wave -noupdate /tb/dut/rst
add wave -noupdate /tb/dut/s_axis_tdata
add wave -noupdate -color Yellow /tb/s_axis_tdata_monitor
add wave -noupdate -color Yellow /tb/dut/s_axis_tvalid
add wave -noupdate /tb/dut/s_axis_tready
add wave -noupdate /tb/dut/s_axis_tlast
add wave -noupdate /tb/dut/is_ipv4
add wave -noupdate /tb/dut/is_ipv6
add wave -noupdate -radix unsigned /tb/dut/pkt_length_ipv4
add wave -noupdate -radix unsigned /tb/dut/pkt_length_ipv6
add wave -noupdate /tb/dut/hdr_chk_pass
add wave -noupdate -divider {New Divider}
add wave -noupdate /tb/dut/wr_ptr
add wave -noupdate /tb/dut/rd_ptr
add wave -noupdate /tb/dut/fifo_full
add wave -noupdate /tb/dut/fifo_empty
add wave -noupdate -expand /tb/dut/fifo_empty_d
add wave -noupdate /tb/dut/ddr_wr_st
add wave -noupdate /tb/dut/astall
add wave -noupdate /tb/dut/wstall
add wave -noupdate /tb/dut/wr_beat_cnt
add wave -noupdate /tb/dut/fifo_rd_en
add wave -noupdate /tb/dut/m_axi_awready
add wave -noupdate -color Magenta /tb/dut/m_axi_awvalid
add wave -noupdate -radix unsigned /tb/dut/m_axi_awaddr
add wave -noupdate /tb/dut/m_axi_awlen
add wave -noupdate /tb/dut/m_axi_awsize
add wave -noupdate /tb/dut/m_axi_awburst
add wave -noupdate /tb/dut/m_axi_wdata
add wave -noupdate -color Magenta /tb/m_axi_wdata_monitor
add wave -noupdate -color Magenta /tb/dut/m_axi_wvalid
add wave -noupdate -color Yellow /tb/dut/m_axi_wready
add wave -noupdate /tb/dut/m_axi_wlast
add wave -noupdate /tb/dut/m_axi_wstrb
add wave -noupdate /tb/dut/m_axi_bready
add wave -noupdate /tb/dut/m_axi_arvalid
add wave -noupdate /tb/dut/m_axi_arready
add wave -noupdate /tb/dut/pkt_dropping
add wave -noupdate -expand /tb/dut/fifo_out_d2
add wave -noupdate /tb/tx_pkt_cnt
add wave -noupdate /tb/rx_pkt_cnt
add wave -noupdate -divider ddr
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2245000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 165
configure wave -valuecolwidth 204
configure wave -justifyvalue left
configure wave -signalnamewidth 1
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
WaveRestoreZoom {0 ps} {3623792 ps}
