// ancestors.rs
//
// Copyright 2018 Georges Racinet <gracinet@anybox.fr>
//
// This software may be used and distributed according to the terms of the
// GNU General Public License version 2 or any later version.

//! Rust versions of generic DAG ancestors algorithms for Mercurial

use super::{Graph, GraphError, Revision, NULL_REVISION};
use std::collections::{BinaryHeap, HashSet};

/// Iterator over the ancestors of a given list of revisions
/// This is a generic type, defined and implemented for any Graph, so that
/// it's easy to
///
/// - unit test in pure Rust
/// - bind to main Mercurial code, potentially in several ways and have these
///   bindings evolve over time
pub struct AncestorsIterator<G: Graph> {
    graph: G,
    visit: BinaryHeap<Revision>,
    seen: HashSet<Revision>,
    stoprev: Revision,
}

impl<G: Graph> AncestorsIterator<G> {
    /// Constructor.
    ///
    /// if `inclusive` is true, then the init revisions are emitted in
    /// particular, otherwise iteration starts from their parents.
    pub fn new<I>(
        graph: G,
        initrevs: I,
        stoprev: Revision,
        inclusive: bool,
    ) -> Result<Self, GraphError>
    where
        I: IntoIterator<Item = Revision>,
    {
        let filtered_initrevs = initrevs.into_iter().filter(|&r| r >= stoprev);
        if inclusive {
            let visit: BinaryHeap<Revision> = filtered_initrevs.collect();
            let seen = visit.iter().map(|&x| x).collect();
            return Ok(AncestorsIterator {
                visit: visit,
                seen: seen,
                stoprev: stoprev,
                graph: graph,
            });
        }
        let mut this = AncestorsIterator {
            visit: BinaryHeap::new(),
            seen: HashSet::new(),
            stoprev: stoprev,
            graph: graph,
        };
        this.seen.insert(NULL_REVISION);
        for rev in filtered_initrevs {
            this.conditionally_push_parents(rev)?;
        }
        Ok(this)
    }

    #[inline]
    fn conditionally_push_rev(&mut self, rev: Revision) {
        if self.stoprev <= rev && !self.seen.contains(&rev) {
            self.seen.insert(rev);
            self.visit.push(rev);
        }
    }

    #[inline]
    fn conditionally_push_parents(
        &mut self,
        rev: Revision,
    ) -> Result<(), GraphError> {
        let parents = self.graph.parents(rev)?;
        self.conditionally_push_rev(parents.0);
        self.conditionally_push_rev(parents.1);
        Ok(())
    }

    /// Consumes partially the iterator to tell if the given target
    /// revision
    /// is in the ancestors it emits.
    /// This is meant for iterators actually dedicated to that kind of
    /// purpose
    pub fn contains(&mut self, target: Revision) -> bool {
        if self.seen.contains(&target) && target != NULL_REVISION {
            return true;
        }
        for rev in self {
            if rev == target {
                return true;
            }
            if rev < target {
                return false;
            }
        }
        false
    }
}

/// Main implementation.
///
/// The algorithm is the same as in `_lazyancestorsiter()` from `ancestors.py`
/// with a few non crucial differences:
///
/// - there's no filtering of invalid parent revisions. Actually, it should be
///   consistent and more efficient to filter them from the end caller.
/// - we don't use the equivalent of `heapq.heapreplace()`, but we should, for
///   the same reasons (using `peek_mut`)
/// - we don't have the optimization for adjacent revs (case where p1 == rev-1)
/// - we save a few pushes by comparing with `stoprev` before pushing
///
/// Error treatment:
/// We swallow the possible GraphError of conditionally_push_parents() to
/// respect the Iterator trait in a simple manner: never emitting parents
/// for the returned revision. We finds this good enough for now, because:
///
/// - there's a good chance that invalid revisionss are fed from the start,
///   and `new()` doesn't swallow the error result.
/// - this is probably what the Python implementation produces anyway, due
///   to filtering at each step, and Python code is currently the only
///   concrete caller we target, so we shouldn't need a finer error treatment
///   for the time being.
impl<G: Graph> Iterator for AncestorsIterator<G> {
    type Item = Revision;

    fn next(&mut self) -> Option<Revision> {
        let current = match self.visit.pop() {
            None => {
                return None;
            }
            Some(i) => i,
        };
        self.conditionally_push_parents(current).unwrap_or(());
        Some(current)
    }
}

#[cfg(test)]
mod tests {

    use super::*;

    #[derive(Clone, Debug)]
    struct Stub;

    /// This is the same as the dict from test-ancestors.py
    impl Graph for Stub {
        fn parents(
            &self,
            rev: Revision,
        ) -> Result<(Revision, Revision), GraphError> {
            match rev {
                0 => Ok((-1, -1)),
                1 => Ok((0, -1)),
                2 => Ok((1, -1)),
                3 => Ok((1, -1)),
                4 => Ok((2, -1)),
                5 => Ok((4, -1)),
                6 => Ok((4, -1)),
                7 => Ok((4, -1)),
                8 => Ok((-1, -1)),
                9 => Ok((6, 7)),
                10 => Ok((5, -1)),
                11 => Ok((3, 7)),
                12 => Ok((9, -1)),
                13 => Ok((8, -1)),
                r => Err(GraphError::ParentOutOfRange(r)),
            }
        }
    }

    fn list_ancestors<G: Graph>(
        graph: G,
        initrevs: Vec<Revision>,
        stoprev: Revision,
        inclusive: bool,
    ) -> Vec<Revision> {
        AncestorsIterator::new(graph, initrevs, stoprev, inclusive)
            .unwrap()
            .collect()
    }

    #[test]
    /// Same tests as test-ancestor.py, without membership
    /// (see also test-ancestor.py.out)
    fn test_list_ancestor() {
        assert_eq!(list_ancestors(Stub, vec![], 0, false), vec![]);
        assert_eq!(
            list_ancestors(Stub, vec![11, 13], 0, false),
            vec![8, 7, 4, 3, 2, 1, 0]
        );
        assert_eq!(list_ancestors(Stub, vec![1, 3], 0, false), vec![1, 0]);
        assert_eq!(
            list_ancestors(Stub, vec![11, 13], 0, true),
            vec![13, 11, 8, 7, 4, 3, 2, 1, 0]
        );
        assert_eq!(list_ancestors(Stub, vec![11, 13], 6, false), vec![8, 7]);
        assert_eq!(
            list_ancestors(Stub, vec![11, 13], 6, true),
            vec![13, 11, 8, 7]
        );
        assert_eq!(list_ancestors(Stub, vec![11, 13], 11, true), vec![13, 11]);
        assert_eq!(list_ancestors(Stub, vec![11, 13], 12, true), vec![13]);
        assert_eq!(
            list_ancestors(Stub, vec![10, 1], 0, true),
            vec![10, 5, 4, 2, 1, 0]
        );
    }

    #[test]
    /// Corner case that's not directly in test-ancestors.py, but
    /// that happens quite often, as demonstrated by running the whole
    /// suite.
    /// For instance, run tests/test-obsolete-checkheads.t
    fn test_nullrev_input() {
        let mut iter =
            AncestorsIterator::new(Stub, vec![-1], 0, false).unwrap();
        assert_eq!(iter.next(), None)
    }

    #[test]
    fn test_contains() {
        let mut lazy =
            AncestorsIterator::new(Stub, vec![10, 1], 0, true).unwrap();
        assert!(lazy.contains(1));
        assert!(!lazy.contains(3));

        let mut lazy =
            AncestorsIterator::new(Stub, vec![0], 0, false).unwrap();
        assert!(!lazy.contains(NULL_REVISION));
    }

    /// A corrupted Graph, supporting error handling tests
    struct Corrupted;

    impl Graph for Corrupted {
        fn parents(
            &self,
            rev: Revision,
        ) -> Result<(Revision, Revision), GraphError> {
            match rev {
                1 => Ok((0, -1)),
                r => Err(GraphError::ParentOutOfRange(r)),
            }
        }
    }

    #[test]
    fn test_initrev_out_of_range() {
        // inclusive=false looks up initrev's parents right away
        match AncestorsIterator::new(Stub, vec![25], 0, false) {
            Ok(_) => panic!("Should have been ParentOutOfRange"),
            Err(e) => assert_eq!(e, GraphError::ParentOutOfRange(25)),
        }
    }

    #[test]
    fn test_next_out_of_range() {
        // inclusive=false looks up initrev's parents right away
        let mut iter =
            AncestorsIterator::new(Corrupted, vec![1], 0, false).unwrap();
        assert_eq!(iter.next(), Some(0));
        assert_eq!(iter.next(), None);
    }
}
