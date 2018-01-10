===================
Mercurial Rust Code
===================

This directory contains various Rust code for the Mercurial project.

The top-level ``Cargo.toml`` file defines a workspace containing
all primary Mercurial crates.

Building
========

To build the Rust components::

   $ cargo build

If you prefer a non-debug / release configuration::

   $ cargo build --release

Features
--------

The following Cargo features are available:

localdev (default)
   Produce files that work with an in-source-tree build.

   In this mode, the build finds and uses a ``python2.7`` binary from
   ``PATH``. The ``hg`` binary assumes it runs from ``rust/target/<target>hg``
   and it finds Mercurial files at ``dirname($0)/../../../``.

Build Mechanism
---------------

The produced ``hg`` binary is *bound* to a CPython installation. The
binary links against and loads a CPython library that is discovered
at build time (by a ``build.rs`` Cargo build script). The Python
standard library defined by this CPython installation is also used.

Finding the appropriate CPython installation to use is done by
the ``python27-sys`` crate's ``build.rs``. Its search order is::

1. ``PYTHON_SYS_EXECUTABLE`` environment variable.
2. ``python`` executable on ``PATH``
3. ``python2`` executable on ``PATH``
4. ``python2.7`` executable on ``PATH``

Additional verification of the found Python will be performed by our
``build.rs`` to ensure it meets Mercurial's requirements.

Details about the build-time configured Python are built into the
produced ``hg`` binary. This means that a built ``hg`` binary is only
suitable for a specific, well-defined role. These roles are controlled
by Cargo features (see above).

Running
=======

The ``hgcli`` crate produces an ``hg`` binary. You can run this binary
via ``cargo run``::

   $ cargo run --manifest-path hgcli/Cargo.toml

Or directly::

   $ target/debug/hg
   $ target/release/hg

You can also run the test harness with this binary::

   $ ./run-tests.py --with-hg ../rust/target/debug/hg

.. note::

   Integration with the test harness is still preliminary. Remember to
   ``cargo build`` after changes because the test harness doesn't yet
   automatically build Rust code.
