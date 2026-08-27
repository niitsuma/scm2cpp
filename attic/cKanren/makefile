.PHONY: all
all:test

.PHONY: test
test :mk.scm unit-test.scm
	 racket unit-test.scm
#	 racket ../common-test.scm


# comp-test : comp-test.cpp comp-test.hpp
# 	g++ comp-test.cpp -o comp-test

# comp-test.cpp : comp-test.scm scm2c.typ scm2c.scm comp-test.hpp
# 	echo "#include \"comp-test.hpp\" " > tmp.txt
# 	cat tmp.txt comp-test.cpp > tmp2.txt
# 	mv tmp2.txt comp-test.cpp
# 	#./scm2c.scm  comp-test.scm


# comp-test.hpp : comp-test.scm scm2c.typ scm2c.scm
# 	racket scm2c.scm
# 	#racket comp-test.scm


#.PHONY: clean
#clean:
#	#rm -f comp-test comp-test.cpp comp-test.hpp tmp.txt tmp2.txt