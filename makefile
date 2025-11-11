.PHONY: build run RUN clean

# 自动查找当前目录下所有的 .v 和 .sv 文件
VERILOG_SOURCES := $(wildcard *.v *.sv)

build:
	clear
	# 检查是否找到了任何 Verilog/SystemVerilog 文件
	@if [ -z "$(VERILOG_SOURCES)" ]; then \
		echo "错误：在当前目录中未找到任何 .v 或 .sv 文件。"; \
		exit 1; \
	fi
	# 打印将要编译的文件列表
	@echo "正在编译以下文件:"
	@echo "$(VERILOG_SOURCES)"
	# 运行 Verilator，传入所有找到的源文件
	verilator --trace -cc $(VERILOG_SOURCES) --exe tb_shake.cpp --top-module SHAKE_wrapper -Mdir obj_dir
	$(MAKE) -C obj_dir -f VSHAKE_wrapper.mk VSHAKE_wrapper

run: build
	./obj_dir/VSHAKE_wrapper

RUN: run

clean:
	rm -rf obj_dir waveform.vcd