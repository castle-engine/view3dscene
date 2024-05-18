#!/bin/bash
set -eu

# ----------------------------------------------------------------------------
# Build castle-model-viewer and castle-model-converter,
# run various tests on models in directories given as arguments ($@),
# compare with output stored in repo.
#
# This bash script uses settings similar to bash strict mode, for similar reasons,
# see http://redsymbol.net/articles/unofficial-bash-strict-mode/
# ----------------------------------------------------------------------------

# run tests
jenkins_scripts/run_tests_on_dir.sh run_tests_output.txt run_tests_output_verbose.txt "$@"

# remove OpenAL trash from outpt
sed --in-place=.bak \
  -e '/ALSA lib/d' \
  -e '/AL lib/d' \
  -e '/jack server is not running or cannot be started/d' \
  -e '/JackShmReadWritePtr/d' \
  -e '/Cannot connect to server/d' \
  run_tests_output.txt

# replace current dir (present in some output messages) with string "DIR",
# to make the result reproducible, regardless of the current directory.
REPOSITORY_DIR="`pwd`"
# REPOSITORY_DIR="`dirname \"$REPOSITORY_DIR\"`" # go to parent -- not anymore
sed --in-place=.bak2 -e "s|${REPOSITORY_DIR}|DIR|g" run_tests_output.txt

cat run_tests_output.txt

# compare with last correct output
#
# TODO: -w added only temporarily, since "Possible reasons:" was for some time
# with extra space in CGE repo, but in "run_tests_valid_output.txt" has
# trimmed space. Once CGE updates, it should be everywhere without space,
# and -w can be removed below.

diff -wu run_tests_output.txt jenkins_scripts/run_tests_valid_output.txt
