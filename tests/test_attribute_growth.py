"""Compare runtime class gains against statically interpreted original bytes."""
from pathlib import Path
import ast,re,sys,unittest
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from attribute_growth import recover
BINARY=ROOT/'originals/1-RedMoonServe-RaGEZONE-/Bin/svMapServer.exe'

@unittest.skipUnless(BINARY.exists(),'Original server input not installed')
class AttributeGrowth(unittest.TestCase):
    def test_runtime_matches_native_constructor(self):
        report=recover(BINARY)
        source=(ROOT/'game/scripts/recovered_combat.gd').read_text()
        table=ast.literal_eval(re.search(r'^const GROWTH = (.+)$',source,re.M)[1])
        self.assertEqual(table,report['server_class_growth'])
        self.assertEqual(table[1],[10,18,8,12])
        self.assertEqual(table[6],[10,15,13,10])
        self.assertEqual(table[7],[12,12,12,12])

if __name__=='__main__':unittest.main()
