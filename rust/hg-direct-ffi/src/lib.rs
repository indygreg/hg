// Copyright 2018 Georges Racinet <gracinet@anybox.fr>
//
// This software may be used and distributed according to the terms of the
// GNU General Public License version 2 or any later version.

//! Bindings for CPython extension code
//!
//! This exposes methods to build and use a `rustlazyancestors` iterator
//! from C code, using an index and its parents function that are passed
//! from the caller at instantiation.

extern crate hg;
extern crate libc;

mod ancestors;
pub use ancestors::{
    rustlazyancestors_contains, rustlazyancestors_drop,
    rustlazyancestors_init, rustlazyancestors_next,
};
