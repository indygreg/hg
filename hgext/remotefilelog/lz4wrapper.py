from __future__ import absolute_import

from mercurial.i18n import _
from mercurial import (
    demandimport,
    error,
    util,
)
if util.safehasattr(demandimport, 'IGNORES'):
    # Since 670eb4fa1b86
    demandimport.IGNORES.update(['pkgutil', 'pkg_resources', '__main__'])
else:
    demandimport.ignore.extend(['pkgutil', 'pkg_resources', '__main__'])

def missing(*args, **kwargs):
    raise error.Abort(_('remotefilelog extension requires lz4 support'))

lz4compress = lzcompresshc = lz4decompress = missing

with demandimport.deactivated():
    import lz4

    try:
        # newer python-lz4 has these functions deprecated as top-level ones,
        # so we are trying to import from lz4.block first
        def _compressHC(*args, **kwargs):
            return lz4.block.compress(*args, mode='high_compression', **kwargs)
        lzcompresshc = _compressHC
        lz4compress = lz4.block.compress
        lz4decompress = lz4.block.decompress
    except AttributeError:
        try:
            lzcompresshc = lz4.compressHC
            lz4compress = lz4.compress
            lz4decompress = lz4.decompress
        except AttributeError:
            pass
