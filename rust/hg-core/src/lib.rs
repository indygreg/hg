// Copyright 2018 Georges Racinet <gracinet@anybox.fr>
//
// This software may be used and distributed according to the terms of the
// GNU General Public License version 2 or any later version.
mod ancestors;
pub use ancestors::AncestorsIterator;

/// Mercurial revision numbers
///
/// As noted in revlog.c, revision numbers are actually encoded in
/// 4 bytes, and are liberally converted to ints, whence the i32
pub type Revision = i32;

pub const NULL_REVISION: Revision = -1;

/// The simplest expression of what we need of Mercurial DAGs.
pub trait Graph {
    fn parents(&self, Revision) -> Result<(Revision, Revision), GraphError>;
}

#[derive(Clone, Debug, PartialEq)]
pub enum GraphError {
    ParentOutOfRange(Revision),
}
