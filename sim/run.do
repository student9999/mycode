vlog ../*.sv
vsim -voptargs=+acc work.tb
log -r /*
do wave.do
run -all