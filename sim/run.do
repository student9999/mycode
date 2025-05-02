vlog ../*.sv
vsim -voptargs=+acc work.tb_mrmac_2_ddr
log -r /*
do wave.do
run -all