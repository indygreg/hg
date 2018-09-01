#require test-repo

  $ . "$TESTDIR/helpers-testrepo.sh"
  $ cd "$TESTDIR"/..

  $ testrepohg files 'set:(**.py)' \
  > -X hgdemandimport/demandimportpy2.py \
  > -X mercurial/thirdparty/cbor \
  > | sed 's|\\|/|g' | xargs $PYTHON contrib/check-py3-compat.py
  contrib/python-zstandard/setup.py not using absolute_import
  contrib/python-zstandard/setup_zstd.py not using absolute_import
  contrib/python-zstandard/tests/common.py not using absolute_import
  contrib/python-zstandard/tests/test_buffer_util.py not using absolute_import
  contrib/python-zstandard/tests/test_compressor.py not using absolute_import
  contrib/python-zstandard/tests/test_compressor_fuzzing.py not using absolute_import
  contrib/python-zstandard/tests/test_data_structures.py not using absolute_import
  contrib/python-zstandard/tests/test_data_structures_fuzzing.py not using absolute_import
  contrib/python-zstandard/tests/test_decompressor.py not using absolute_import
  contrib/python-zstandard/tests/test_decompressor_fuzzing.py not using absolute_import
  contrib/python-zstandard/tests/test_estimate_sizes.py not using absolute_import
  contrib/python-zstandard/tests/test_module_attributes.py not using absolute_import
  contrib/python-zstandard/tests/test_train_dictionary.py not using absolute_import
  setup.py not using absolute_import

#if py3exe
  $ testrepohg files 'set:(**.py) - grep(pygments)' \
  > -X hgdemandimport/demandimportpy2.py \
  > -X hgext/fsmonitor/pywatchman \
  > -X mercurial/cffi \
  > -X mercurial/thirdparty \
  > | sed 's|\\|/|g' | xargs python3 contrib/check-py3-compat.py \
  > | sed 's/[0-9][0-9]*)$/*)/'

#endif

#if py3exe py3pygments
  $ testrepohg files 'set:(**.py) and grep(pygments)' | sed 's|\\|/|g' \
  > | xargs python3 contrib/check-py3-compat.py \
  > | sed 's/[0-9][0-9]*)$/*)/'
#endif
