.PHONY: all dist bindist

all:
	python scons.py || echo -e "\e[1;31mCompilation failed. Did you read http://www.openkore.com/wiki/index.php/How_to_run_OpenKore_on_Linux/Unix ?\e[0m"

dist:
	bash makedist.sh

bindist:
	bash makedist.sh --bin
