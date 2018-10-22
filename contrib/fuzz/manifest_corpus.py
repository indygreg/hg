from __future__ import absolute_import, print_function

import argparse
import zipfile

ap = argparse.ArgumentParser()
ap.add_argument("out", metavar="some.zip", type=str, nargs=1)
args = ap.parse_args()

with zipfile.ZipFile(args.out[0], "w", zipfile.ZIP_STORED) as zf:
    zf.writestr("manifest_zero",
'''PKG-INFO\09b3ed8f2b81095a13064402e930565f083346e9a
README\080b6e76643dcb44d4bc729e932fc464b3e36dbe3
hg\0b6444347c629cc058d478023905cfb83b7f5bb9d
mercurial/__init__.py\0b80de5d138758541c5f05265ad144ab9fa86d1db
mercurial/byterange.py\017f5a9fbd99622f31a392c33ac1e903925dc80ed
mercurial/fancyopts.py\0b6f52e23e356748c5039313d8b639cda16bf67ba
mercurial/hg.py\023cc12f225f1b42f32dc0d897a4f95a38ddc8f4a
mercurial/mdiff.py\0a05f65c44bfbeec6a42336cd2ff0b30217899ca3
mercurial/revlog.py\0217bc3fde6d82c0210cf56aeae11d05a03f35b2b
mercurial/transaction.py\09d180df101dc14ce3dd582fd998b36c98b3e39aa
notes.txt\0703afcec5edb749cf5cec67831f554d6da13f2fb
setup.py\0ccf3f6daf0f13101ca73631f7a1769e328b472c9
tkmerge\03c922edb43a9c143682f7bc7b00f98b3c756ebe7
''')
    zf.writestr("badmanifest_shorthashes",
                "narf\0aa\nnarf2\0aaa\n")
    zf.writestr("badmanifest_nonull",
                "narf\0cccccccccccccccccccccccccccccccccccccccc\n"
                "narf2aaaaaaaaaaaaaaaaaaaa\n")
