  > evolution.createmarkers=True
  > evolution.createmarkers=True
  > evolution.allowunstable=True
  $ hg amend --note 'yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy'
  abort: cannot store a note of more than 255 bytes
  [255]
  112478962961147124edd43549aedd1a335e44bf be169c7e8dbe21cd10b3d79691cbe7f241e3c21c 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '8', 'operation': 'amend', 'user': 'test'}
  be169c7e8dbe21cd10b3d79691cbe7f241e3c21c 16084da537dd8f84cfdb3055c633772269d62e1b 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '8', 'note': 'adding bar', 'operation': 'amend', 'user': 'test'}