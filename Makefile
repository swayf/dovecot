compile:
	@iced -o lib -c src
	@iced -c test

test: compile
	@node node_modules/lab/bin/lab

test-cov: compile
	@node node_modules/lab/bin/lab -r threshold -t 100

test-cov-html: compile
	@node node_modules/lab/bin/lab -r html -o coverage.html

.PHONY: compile test test-cov test-cov-html

