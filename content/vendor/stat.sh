# BSD find, stat
find . -type f -mindepth 2 -exec stat -f '%N	%z' {} \; | sort > stat.txt
