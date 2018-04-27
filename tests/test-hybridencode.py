from __future__ import absolute_import, print_function

import unittest

from mercurial import (
    store,
)

class hybridencodetests(unittest.TestCase):
    def hybridencode(self, input, want):

        # Check the C implementation if it's in use
        got = store._pathencode(input)
        self.assertEqual(want, got)
        # Check the reference implementation in Python
        refgot = store._hybridencode(input, True)
        self.assertEqual(want, refgot)

    def testnoencodingrequired(self):
        self.hybridencode(
            b'data/abcdefghijklmnopqrstuvwxyz0123456789 !#%&\'()+,-.;=[]^`{}',
            b'data/abcdefghijklmnopqrstuvwxyz0123456789 !#%&\'()+,-.;=[]^`{}')

    def testuppercasechars(self): # uppercase char X is encoded as _x
        self.hybridencode(
            b'data/ABCDEFGHIJKLMNOPQRSTUVWXYZ',
            b'data/_a_b_c_d_e_f_g_h_i_j_k_l_m_n_o_p_q_r_s_t_u_v_w_x_y_z')

    def testunderbar(self): # underbar is doubled
        self.hybridencode(b'data/_', b'data/__')

    def testtilde(self): # tilde is character-encoded
        self.hybridencode(b'data/~', b'data/~7e')

    def testcontrolchars(self): # characters in ASCII code range 1..31
        self.hybridencode(
            (b'data/\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\x0c\r\x0e\x0f'
             b'\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e'
             b'\x1f'),
            (b'data/~01~02~03~04~05~06~07~08~09~0a~0b~0c~0d~0e~0f~10~11~12~13'
             b'~14~15~16~17~18~19~1a~1b~1c~1d~1e~1f'))

    def testhighascii(self):# characters in ASCII code range 126..255
        self.hybridencode(
            (b'data/~\x7f\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c'
             b'\x8d\x8e\x8f\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b'
             b'\x9c\x9d\x9e\x9f'),
            (b'data/~7e~7f~80~81~82~83~84~85~86~87~88~89~8a~8b~8c~8d~8e~8f~90'
             b'~91~92~93~94~95~96~97~98~99~9a~9b~9c~9d~9e~9f'))
        self.hybridencode(
            (b'data/\xa0\xa1\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xab\xac\xad'
             b'\xae\xaf\xb0\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc'
             b'\xbd\xbe\xbf'),
            (b'data/~a0~a1~a2~a3~a4~a5~a6~a7~a8~a9~aa~ab~ac~ad~ae~af~b0~b1~b2'
             b'~b3~b4~b5~b6~b7~b8~b9~ba~bb~bc~bd~be~bf'))
        self.hybridencode(
            (b'data/\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca'
             b'\xcb\xcc\xcd\xce\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6'
             b'\xd7\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf'),
            (b'data/~c0~c1~c2~c3~c4~c5~c6~c7~c8~c9~ca~cb~cc~cd~ce~cf~d0~d1~d2'
             b'~d3~d4~d5~d6~d7~d8~d9~da~db~dc~dd~de~df'))
        self.hybridencode(
            (b'data/\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed'
             b'\xee\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd'
             b'\xfe\xff'),
            (b'data/~e0~e1~e2~e3~e4~e5~e6~e7~e8~e9~ea~eb~ec~ed~ee~ef~f0~f1~f2'
             b'~f3~f4~f5~f6~f7~f8~f9~fa~fb~fc~fd~fe~ff'))

    def testwinreserved(self): # Windows reserved characters
        self.hybridencode(
            (b'data/less <, greater >, colon :, double-quote ", backslash \\, '
             b'pipe |, question-mark ?, asterisk *'),
            (b'data/less ~3c, greater ~3e, colon ~3a, double-quote ~22, '
             b'backslash ~5c, pipe ~7c, question-mark ~3f, asterisk ~2a'))

    def testhgreserved(self):
        # encoding directories ending in .hg, .i or .d with '.hg' suffix
        self.hybridencode(b'data/x.h.i/x.hg/x.i/x.d/foo',
                          b'data/x.h.i.hg/x.hg.hg/x.i.hg/x.d.hg/foo')
        self.hybridencode(b'data/a.hg/a.i/a.d/foo',
                          b'data/a.hg.hg/a.i.hg/a.d.hg/foo')
        self.hybridencode(b'data/au.hg/au.i/au.d/foo',
                          b'data/au.hg.hg/au.i.hg/au.d.hg/foo')
        self.hybridencode(b'data/aux.hg/aux.i/aux.d/foo',
                          b'data/au~78.hg.hg/au~78.i.hg/au~78.d.hg/foo')
        self.hybridencode(b'data/auxy.hg/auxy.i/auxy.d/foo',
                          b'data/auxy.hg.hg/auxy.i.hg/auxy.d.hg/foo')
        # but these are not encoded on *filenames*
        self.hybridencode(b'data/foo/x.hg', b'data/foo/x.hg')
        self.hybridencode(b'data/foo/x.i', b'data/foo/x.i')
        self.hybridencode(b'data/foo/x.d', b'data/foo/x.d')
        self.hybridencode(b'data/foo/a.hg', b'data/foo/a.hg')
        self.hybridencode(b'data/foo/a.i', b'data/foo/a.i')
        self.hybridencode(b'data/foo/a.d', b'data/foo/a.d')
        self.hybridencode(b'data/foo/au.hg', b'data/foo/au.hg')
        self.hybridencode(b'data/foo/au.i', b'data/foo/au.i')
        self.hybridencode(b'data/foo/au.d', b'data/foo/au.d')
        self.hybridencode(b'data/foo/aux.hg', b'data/foo/au~78.hg')
        self.hybridencode(b'data/foo/aux.i', b'data/foo/au~78.i')
        self.hybridencode(b'data/foo/aux.d', b'data/foo/au~78.d')
        self.hybridencode(b'data/foo/auxy.hg', b'data/foo/auxy.hg')
        self.hybridencode(b'data/foo/auxy.i', b'data/foo/auxy.i')
        self.hybridencode(b'data/foo/auxy.d', b'data/foo/auxy.d')

        # plain .hg, .i and .d directories have the leading dot encoded
        self.hybridencode(b'data/.hg/.i/.d/foo',
                          b'data/~2ehg.hg/~2ei.hg/~2ed.hg/foo')

    def testmisclongcases(self):
        self.hybridencode(
            (b'data/aux.bla/bla.aux/prn/PRN/lpt/com3/nul/'
             b'coma/foo.NUL/normal.c.i'),
            (b'data/au~78.bla/bla.aux/pr~6e/_p_r_n/lpt/co~6d3'
             b'/nu~6c/coma/foo._n_u_l/normal.c.i'))
        self.hybridencode(
            (b'data/AUX/SECOND/X.PRN/FOURTH/FI:FTH/SIXTH/SEVENTH/EIGHTH/NINETH'
             b'/TENTH/ELEVENTH/LOREMIPSUM.TXT.i'),
            (b'dh/au~78/second/x.prn/fourth/fi~3afth/sixth/seventh/eighth/'
             b'nineth/tenth/loremia20419e358ddff1bf8751e38288aff1d7c32ec05.i'))
        self.hybridencode(
            (b'data/enterprise/openesbaddons/contrib-imola/corba-bc/'
             b'netbeansplugin/wsdlExtension/src/main/java/META-INF/services'
             b'/org.netbeans.modules.xml.wsdl.bindingsupport.spi.'
             b'ExtensibilityElementTemplateProvider.i'),
            (b'dh/enterpri/openesba/contrib-/corba-bc/netbeans/wsdlexte/src/'
             b'main/java/org.net7018f27961fdf338a598a40c4683429e7ffb9743.i'))
        self.hybridencode(
            (b'data/AUX.THE-QUICK-BROWN-FOX-JU:MPS-OVER-THE-LAZY-DOG-THE-'
             b'QUICK-BROWN-FOX-JUMPS-OVER-THE-LAZY-DOG.TXT.i'),
            (b'dh/au~78.the-quick-brown-fox-ju~3amps-over-the-lazy-dog-the-'
             b'quick-brown-fox-jud4dcadd033000ab2b26eb66bae1906bcb15d4a70.i'))
        self.hybridencode(
            (b'data/Project Planning/Resources/AnotherLongDirectoryName/Follow'
             b'edbyanother/AndAnother/AndThenAnExtremelyLongFileName.txt'),
            (b'dh/project_/resource/anotherl/followed/andanoth/andthenanextrem'
             b'elylongfilenaf93030515d9849cfdca52937c2204d19f83913e5.txt'))
        self.hybridencode(
            (b'data/Project.Planning/Resources/AnotherLongDirectoryName/Follo'
             b'wedbyanother/AndAnother/AndThenAnExtremelyLongFileName.txt'),
            (b'dh/project_/resource/anotherl/followed/andanoth/andthenanextre'
             b'melylongfilena0fd7c506f5c9d58204444fc67e9499006bd2d445.txt'))
        self.hybridencode(
            b'data/foo.../foo   / /a./_. /__/.x../    bla/.FOO/something.i',
            (b'data/foo..~2e/foo  ~20/~20/a~2e/__.~20/____/~2ex.~2e/~20   bla/'
             b'~2e_f_o_o/something.i'))
        self.hybridencode(
            b'data/c/co/com/com0/com1/com2/com3/com4/com5/com6/com7/com8/com9',
            (b'data/c/co/com/com0/co~6d1/co~6d2/co~6d3/co~6d4/co~6d5/co~6d6/'
             b'co~6d7/co~6d8/co~6d9'))
        self.hybridencode(
            b'data/C/CO/COM/COM0/COM1/COM2/COM3/COM4/COM5/COM6/COM7/COM8/COM9',
            (b'data/_c/_c_o/_c_o_m/_c_o_m0/_c_o_m1/_c_o_m2/_c_o_m3/_c_o_m4/'
             b'_c_o_m5/_c_o_m6/_c_o_m7/_c_o_m8/_c_o_m9'))
        self.hybridencode(
            (b'data/c.x/co.x/com.x/com0.x/com1.x/com2.x/com3.x/com4.x/com5.x/'
             b'com6.x/com7.x/com8.x/com9.x'),
            (b'data/c.x/co.x/com.x/com0.x/co~6d1.x/co~6d2.x/co~6d3.x/co~6d4.x'
             b'/co~6d5.x/co~6d6.x/co~6d7.x/co~6d8.x/co~6d9.x'))
        self.hybridencode(
            (b'data/x.c/x.co/x.com0/x.com1/x.com2/x.com3/x.com4/x.com5/x.com6'
             b'/x.com7/x.com8/x.com9'),
            (b'data/x.c/x.co/x.com0/x.com1/x.com2/x.com3/x.com4/x.com5/x.com6'
             b'/x.com7/x.com8/x.com9'))
        self.hybridencode(
            (b'data/cx/cox/comx/com0x/com1x/com2x/com3x/com4x/com5x/com6x/'
             b'com7x/com8x/com9x'),
            (b'data/cx/cox/comx/com0x/com1x/com2x/com3x/com4x/com5x/com6x/'
             b'com7x/com8x/com9x'))
        self.hybridencode(
            (b'data/xc/xco/xcom0/xcom1/xcom2/xcom3/xcom4/xcom5/xcom6/xcom7/'
             b'xcom8/xcom9'),
            (b'data/xc/xco/xcom0/xcom1/xcom2/xcom3/xcom4/xcom5/xcom6/xcom7/'
             b'xcom8/xcom9'))
        self.hybridencode(
            b'data/l/lp/lpt/lpt0/lpt1/lpt2/lpt3/lpt4/lpt5/lpt6/lpt7/lpt8/lpt9',
            (b'data/l/lp/lpt/lpt0/lp~741/lp~742/lp~743/lp~744/lp~745/lp~746/'
             b'lp~747/lp~748/lp~749'))
        self.hybridencode(
            b'data/L/LP/LPT/LPT0/LPT1/LPT2/LPT3/LPT4/LPT5/LPT6/LPT7/LPT8/LPT9',
            (b'data/_l/_l_p/_l_p_t/_l_p_t0/_l_p_t1/_l_p_t2/_l_p_t3/_l_p_t4/'
             b'_l_p_t5/_l_p_t6/_l_p_t7/_l_p_t8/_l_p_t9'))
        self.hybridencode(
            (b'data/l.x/lp.x/lpt.x/lpt0.x/lpt1.x/lpt2.x/lpt3.x/lpt4.x/lpt5.x/'
             b'lpt6.x/lpt7.x/lpt8.x/lpt9.x'),
            (b'data/l.x/lp.x/lpt.x/lpt0.x/lp~741.x/lp~742.x/lp~743.x/lp~744.x/'
             b'lp~745.x/lp~746.x/lp~747.x/lp~748.x/lp~749.x'))
        self.hybridencode(
            (b'data/x.l/x.lp/x.lpt/x.lpt0/x.lpt1/x.lpt2/x.lpt3/x.lpt4/x.lpt5/'
             b'x.lpt6/x.lpt7/x.lpt8/x.lpt9'),
            (b'data/x.l/x.lp/x.lpt/x.lpt0/x.lpt1/x.lpt2/x.lpt3/x.lpt4/x.lpt5'
             b'/x.lpt6/x.lpt7/x.lpt8/x.lpt9'))
        self.hybridencode(
            (b'data/lx/lpx/lptx/lpt0x/lpt1x/lpt2x/lpt3x/lpt4x/lpt5x/lpt6x/'
             b'lpt7x/lpt8x/lpt9x'),
            (b'data/lx/lpx/lptx/lpt0x/lpt1x/lpt2x/lpt3x/lpt4x/lpt5x/lpt6x/'
             b'lpt7x/lpt8x/lpt9x'))
        self.hybridencode(
            (b'data/xl/xlp/xlpt/xlpt0/xlpt1/xlpt2/xlpt3/xlpt4/xlpt5/xlpt6/'
             b'xlpt7/xlpt8/xlpt9'),
            (b'data/xl/xlp/xlpt/xlpt0/xlpt1/xlpt2/xlpt3/xlpt4/xlpt5/xlpt6/'
             b'xlpt7/xlpt8/xlpt9'))
        self.hybridencode(b'data/con/p/pr/prn/a/au/aux/n/nu/nul',
                          b'data/co~6e/p/pr/pr~6e/a/au/au~78/n/nu/nu~6c')
        self.hybridencode(
            b'data/CON/P/PR/PRN/A/AU/AUX/N/NU/NUL',
            b'data/_c_o_n/_p/_p_r/_p_r_n/_a/_a_u/_a_u_x/_n/_n_u/_n_u_l')
        self.hybridencode(
            b'data/con.x/p.x/pr.x/prn.x/a.x/au.x/aux.x/n.x/nu.x/nul.x',
            b'data/co~6e.x/p.x/pr.x/pr~6e.x/a.x/au.x/au~78.x/n.x/nu.x/nu~6c.x')
        self.hybridencode(
            b'data/x.con/x.p/x.pr/x.prn/x.a/x.au/x.aux/x.n/x.nu/x.nul',
            b'data/x.con/x.p/x.pr/x.prn/x.a/x.au/x.aux/x.n/x.nu/x.nul')
        self.hybridencode(b'data/conx/px/prx/prnx/ax/aux/auxx/nx/nux/nulx',
                          b'data/conx/px/prx/prnx/ax/au~78/auxx/nx/nux/nulx')
        self.hybridencode(b'data/xcon/xp/xpr/xprn/xa/xau/xaux/xn/xnu/xnul',
                          b'data/xcon/xp/xpr/xprn/xa/xau/xaux/xn/xnu/xnul')
        self.hybridencode(b'data/a./au./aux./auxy./aux.',
                          b'data/a~2e/au~2e/au~78~2e/auxy~2e/au~78~2e')
        self.hybridencode(b'data/c./co./con./cony./con.',
                          b'data/c~2e/co~2e/co~6e~2e/cony~2e/co~6e~2e')
        self.hybridencode(b'data/p./pr./prn./prny./prn.',
                          b'data/p~2e/pr~2e/pr~6e~2e/prny~2e/pr~6e~2e')
        self.hybridencode(b'data/n./nu./nul./nuly./nul.',
                          b'data/n~2e/nu~2e/nu~6c~2e/nuly~2e/nu~6c~2e')
        self.hybridencode(
            b'data/l./lp./lpt./lpt1./lpt1y./lpt1.',
            b'data/l~2e/lp~2e/lpt~2e/lp~741~2e/lpt1y~2e/lp~741~2e')
        self.hybridencode(b'data/lpt9./lpt9y./lpt9.',
                          b'data/lp~749~2e/lpt9y~2e/lp~749~2e')
        self.hybridencode(b'data/com./com1./com1y./com1.',
                          b'data/com~2e/co~6d1~2e/com1y~2e/co~6d1~2e')
        self.hybridencode(b'data/com9./com9y./com9.',
                          b'data/co~6d9~2e/com9y~2e/co~6d9~2e')
        self.hybridencode(b'data/a /au /aux /auxy /aux ',
                          b'data/a~20/au~20/aux~20/auxy~20/aux~20')

    def testhashingboundarycases(self):
        # largest unhashed path
        self.hybridencode(
            (b'data/123456789-123456789-123456789-123456789-123456789-unhashed'
             b'--xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12345'),
            (b'data/123456789-123456789-123456789-123456789-123456789-unhashed'
             b'--xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12345'))
        # shortest hashed path
        self.hybridencode(
            (b'data/123456789-123456789-123456789-123456789-123456789-hashed'
             b'----xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/123456789-123456789-123456789-123456789-123456789-hashed---'
             b'-xxxxxxxxx-xxxxxxxe9c55002b50bf5181e7a6fc1f60b126e2a6fcf71'))

    def testhashing(self):
        # changing one char in part that's hashed away produces a different hash
        self.hybridencode(
            (b'data/123456789-123456789-123456789-123456789-123456789-hashed'
             b'----xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxy-123456789-123456'),
            (b'dh/123456789-123456789-123456789-123456789-123456789-hashed---'
             b'-xxxxxxxxx-xxxxxxxd24fa4455faf8a94350c18e5eace7c2bb17af706'))
        # uppercase hitting length limit due to encoding
        self.hybridencode(
            (b'data/A23456789-123456789-123456789-123456789-123456789-'
             b'xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-'
             b'123456789-12345'),
            (b'dh/a23456789-123456789-123456789-123456789-123456789-'
             b'xxxxxxxxx-xxxxxxxxx-xxxxxxx'
             b'cbbc657029b41b94ed510d05feb6716a5c03bc6b'))
        self.hybridencode(
            (b'data/Z23456789-123456789-123456789-123456789-123456789-'
             b'xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-'
             b'123456789-12345'),
            (b'dh/z23456789-123456789-123456789-123456789-123456789-xxxxxxxxx'
             b'-xxxxxxxxx-xxxxxxx938f32a725c89512833fb96b6602dd9ebff51ddd'))
        # compare with lowercase not hitting limit
        self.hybridencode(
            (b'data/a23456789-123456789-123456789-123456789-123456789-'
             b'xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-'
             b'12345'),
            (b'data/a23456789-123456789-123456789-123456789-123456789-'
             b'xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-'
             b'12345'))
        self.hybridencode(
            (b'data/z23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789'
             b'-12345'),
            (b'data/z23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-'
             b'12345'))
        # not hitting limit with any of these
        self.hybridencode(
            (b'data/abcdefghijklmnopqrstuvwxyz0123456789 !#%&\'()+,-.;=[]^`{}'
             b'xxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12345'),
            (b'data/abcdefghijklmnopqrstuvwxyz0123456789 !#%&\'()+,-.;=[]^`{}'
             b'xxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12345'))
        # underbar hitting length limit due to encoding
        self.hybridencode(
            (b'data/_23456789-123456789-123456789-123456789-123456789-'
             b'xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-'
             b'12345'),
            (b'dh/_23456789-123456789-123456789-123456789-123456789-xxxxxxxxx-'
             b'xxxxxxxxx-xxxxxxx9921a01af50feeabc060ce00eee4cba6efc31d2b'))

        # tilde hitting length limit due to encoding
        self.hybridencode(
            (b'data/~23456789-123456789-123456789-123456789-123456789-'
             b'xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-'
             b'12345'),
            (b'dh/~7e23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'9cec6f97d569c10995f785720044ea2e4227481b'))

    def testwinreservedoverlimit(self):
        # Windows reserved characters hitting length limit
        self.hybridencode(
            (b'data/<23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-12345'),
            (b'dh/~3c23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxee'
             b'67d8f275876ca1ef2500fc542e63c885c4e62d'))
        self.hybridencode(
            (b'data/>23456789-123456789-123456789-123456789-123456789-'
             b'xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-'
             b'123456789-12345'),
            (b'dh/~3e23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'387a85a5b1547cc9136310c974df716818458ddb'))
        self.hybridencode(
            (b'data/:23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-'
             b'123456789-12345'),
            (b'dh/~3a23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'2e4154fb571d13d22399c58cc4ef4858e4b75999'))
        self.hybridencode(
            (b'data/"23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-12345'),
            (b'dh/~2223456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'fc7e3ec7b0687ee06ed8c32fef0eb0c1980259f5'))
        self.hybridencode(
            (b'data/\\23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-'
             b'123456789-12345'),
            (b'dh/~5c23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'944e1f2b7110687e116e0d151328ac648b06ab4a'))
        self.hybridencode(
            (b'data/|23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-12345'),
            (b'dh/~7c23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'28b23dd3fd0242946334126ab62bcd772aac32f4'))
        self.hybridencode(
            (b'data/?23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-12345'),
            (b'dh/~3f23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'a263022d3994d2143d98f94f431eef8b5e7e0f8a'))
        self.hybridencode(
            (b'data/*23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-'
             b'123456789-12345'),
            (b'dh/~2a23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'0e7e6020e3c00ba7bb7893d84ca2966fbf53e140'))

    def testinitialspacelenlimit(self):
        # initial space hitting length limit
        self.hybridencode(
            (b'data/ 23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-'
             b'123456789-12345'),
            (b'dh/~2023456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'92acbc78ef8c0b796111629a02601f07d8aec4ea'))

    def testinitialdotlenlimit(self):
        # initial dot hitting length limit
        self.hybridencode(
            (b'data/.23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-12345'),
            (b'dh/~2e23456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'dbe19cc6505b3515ab9228cebf877ad07075168f'))

    def testtrailingspacelenlimit(self):
        # trailing space in filename hitting length limit
        self.hybridencode(
            (b'data/123456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-'
             b'123456789-1234 '),
            (b'dh/123456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxx'
             b'0025dc73e04f97426db4893e3bf67d581dc6d066'))

    def testtrailingdotlenlimit(self):
        # trailing dot in filename hitting length limit
        self.hybridencode(
            (b'data/123456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-'
             b'1234.'),
            (b'dh/123456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxx'
             b'85a16cf03ee7feba8a5abc626f1ba9886d01e89d'))

    def testinitialspacedirlenlimit(self):
        # initial space in directory hitting length limit
        self.hybridencode(
            (b'data/ x/456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-12345'),
            (b'dh/~20x/456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'1b3a3b712b2ac00d6af14ae8b4c14fdbf904f516'))

    def testinitialdotdirlenlimit(self):
        # initial dot in directory hitting length limit
        self.hybridencode(
            (b'data/.x/456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-12345'),
            (b'dh/~2ex/456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'39dbc4c193a5643a8936fc69c3363cd7ac91ab14'))

    def testtrailspacedirlenlimit(self):
        # trailing space in directory hitting length limit
        self.hybridencode(
            (b'data/x /456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-12345'),
            (b'dh/x~20/456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'2253c341df0b5290790ad312cd8499850f2273e5'))

    def testtrailingdotdirlenlimit(self):
        # trailing dot in directory hitting length limit
        self.hybridencode(
            (b'data/x./456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-'
             b'123456789-12345'),
            (b'dh/x~2e/456789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'cc0324d696d34562b44b5138db08ee1594ccc583'))

    def testdirencodinglenlimit(self):
        # with directories that need direncoding, hitting length limit
        self.hybridencode(
            (b'data/x.i/56789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-'
             b'12345'),
            (b'dh/x.i.hg/56789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxx'
             b'a4c4399bdf81c67dbbbb7060aa0124d8dea94f74'))
        self.hybridencode(
            (b'data/x.d/56789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-12345'),
            (b'dh/x.d.hg/56789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxx'
             b'1303fa90473b230615f5b3ea7b660e881ae5270a'))
        self.hybridencode(
            (b'data/x.hg/5789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-12345'),
            (b'dh/x.hg.hg/5789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxx'
             b'26d724a8af68e7a4e4455e6602ea9adbd0eb801f'))

    def testwinreservedfilenameslimit(self):
        # Windows reserved filenames, hitting length limit
        self.hybridencode(
            (b'data/con/56789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-'
             b'123456789-12345'),
            (b'dh/co~6e/56789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'c0794d4f4c605a2617900eb2563d7113cf6ea7d3'))
        self.hybridencode(
            (b'data/prn/56789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-12345'),
            (b'dh/pr~6e/56789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'64db876e1a9730e27236cb9b167aff942240e932'))
        self.hybridencode(
            (b'data/aux/56789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-12345'),
            (b'dh/au~78/56789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'8a178558405ca6fb4bbd75446dfa186f06751a0d'))
        self.hybridencode(
            (b'data/nul/56789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-12345'),
            (b'dh/nu~6c/56789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'c5e51b6fec1bd07bd243b053a0c3f7209855b886'))
        self.hybridencode(
            (b'data/com1/6789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-12345'),
            (b'dh/co~6d1/6789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'32f5f44ece3bb62b9327369ca84cc19c86259fcd'))
        self.hybridencode(
            (b'data/com9/6789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-12345'),
            (b'dh/co~6d9/6789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'734360b28c66a3230f55849fe8926206d229f990'))
        self.hybridencode(
            (b'data/lpt1/6789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-12345'),
            (b'dh/lp~741/6789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'e6f16ab4b6b0637676b2842b3345c9836df46ef7'))
        self.hybridencode(
            (b'data/lpt9/6789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-12345'),
            (b'dh/lp~749/6789-123456789-123456789-123456789-123456789'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxx'
             b'a475814c51acead3e44f2ff801f0c4903f986157'))

    def testnonreservednolimit(self):
        # non-reserved names, just not hitting limit
        self.hybridencode(
            (b'data/123456789-123456789-123456789-123456789-123456789-'
             b'/com/com0/lpt/lpt0/'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12345'),
            (b'data/123456789-123456789-123456789-123456789-123456789-'
             b'/com/com0/lpt/lpt0/'
             b'-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12345'))

    def testhashedpathuntrucfirst(self):
        # hashed path with largest untruncated 1st dir
        self.hybridencode(
            (b'data/12345678/-123456789-123456789-123456789-123456789-hashed'
             b'----xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/-123456789-123456789-123456789-123456789-hashed'
             b'----xxxxxxxxx-xxxxxxx4e9e9e384d00929a93b6835fbf976eb32321ff3c'))

    def testhashedpathsmallesttrucdir(self):
        # hashed path with smallest truncated 1st dir
        self.hybridencode(
            (b'data/123456789/123456789-123456789-123456789-123456789-hashed'
             b'----xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/123456789-123456789-123456789-123456789-hashed'
             b'----xxxxxxxxx-xxxxxxxx1f4e4ec5f2be76e109bfaa8e31c062fe426d5490'))

    def testhashedlargesttwountruc(self):
        # hashed path with largest untruncated two dirs
        self.hybridencode(
            (b'data/12345678/12345678/9-123456789-123456789-123456789-hashed'
             b'----xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/9-123456789-123456789-123456789-hashed'
             b'----xxxxxxxxx-xxxxxxx3332d8329d969cf835542a9f2cbcfb385b6cf39d'))

    def testhashedpathsmallesttrunctwodirs(self):
        # hashed path with smallest truncated two dirs
        self.hybridencode(
            (b'data/123456789/123456789/123456789-123456789-123456789-hashed'
             b'----xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/123456789-123456789-123456789-hashed'
             b'----xxxxxxxxx-xxxxxxxxx'
             b'9699559798247dffa18717138859be5f8874840e'))

    def testhashuntruncthree(self):
        # hashed path with largest untruncated three dirs
        self.hybridencode(
            (b'data/12345678/12345678/12345678/89-123456789-123456789-'
             b'hashed----xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-'
             b'123456789-123456'),
            (b'dh/12345678/12345678/12345678/89-123456789-123456789-hashed'
             b'----xxxxxxxxx-xxxxxxxf0a2b053bb1369cce02f78c217d6a7aaea18c439'))

    def testhashtruncthree(self):
        # hashed path with smallest truncated three dirs
        self.hybridencode(
            (b'data/123456789/123456789/123456789/123456789-123456789-hashed'
             b'----xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/12345678/123456789-123456789-hashed'
             b'----xxxxxxxxx-xxxxxxxxx-'
             b'1c6f8284967384ec13985a046d3553179d9d03cd'))

    def testhashuntrucfour(self):
        # hashed path with largest untruncated four dirs
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/789-123456789-hashed'
             b'----xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/789-123456789-hashed'
             b'----xxxxxxxxx-xxxxxxx0d30c99049d8f0ff97b94d4ef302027e8d54c6fd'))

    def testhashtruncfour(self):
        # hashed path with smallest truncated four dirs
        self.hybridencode(
            (b'data/123456789/123456789/123456789/123456789/123456789-hashed'
             b'----xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/123456789-hashed'
             b'----xxxxxxxxx-xxxxxxxxx-x'
             b'46162779e1a771810b37a737f82ae7ed33771402'))

    def testhashuntruncfive(self):
        # hashed path with largest untruncated five dirs
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/6789-hashed'
             b'----xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/6789-hashed'
             b'----xxxxxxxxx-xxxxxxxbfe752ddc8b003c2790c66a9f2eb1ea75c114390'))

    def testhashtruncfive(self):
        # hashed path with smallest truncated five dirs
        self.hybridencode(
            (b'data/123456789/123456789/123456789/123456789/123456789/hashed'
             b'----xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/hashed'
             b'----xxxxxxxxx-xxxxxxxxx-xx'
             b'b94c27b3532fa880cdd572b1c514785cab7b6ff2'))

    def testhashuntruncsix(self):
        # hashed path with largest untruncated six dirs
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'ed----xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'ed----xxxxxxxxx-xxxxxxx'
             b'cd8cc5483a0f3be409e0e5d4bf9e36e113c59235'))

    def testhashtruncsix(self):
        # hashed path with smallest truncated six dirs
        self.hybridencode(
            (b'data/123456789/123456789/123456789/123456789/123456789/'
              b'123456789/xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-'
              b'123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'xxxxxxxxx-xxxxxxxxx-xxx'
             b'47dd6f616f833a142da00701b334cebbf640da06'))

    def testhashuntrunc7(self):
        # hashed path with largest untruncated seven dirs
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/xxxxxx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-'
             b'123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/xxxxxx-xxxxxxx'
             b'1c8ed635229fc22efe51035feeadeb4c8a0ecb82'))

    def testhashtrunc7(self):
        # hashed path with smallest truncated seven dirs
        self.hybridencode(
            (b'data/123456789/123456789/123456789/123456789/123456789/'
              b'123456789/123456789/'
              b'xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/123'
             b'45678/xxxxxxxxx-xxxx298ff7d33f8ce6db57930837ffea2fb2f48bb926'))

    def testhashuntrunc8(self):
        # hashed path with largest untruncated eight dirs
        # (directory 8 is dropped because it hits _maxshortdirslen)
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'12345678/12345678/xxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/1'
             b'2345678/xxxxxxx-xxxxxxc8996ccd41b471f768057181a4d59d2febe7277d'))

    def testhashtrunc8(self):
        # hashed path with smallest truncated eight dirs
        # (directory 8 is dropped because it hits _maxshortdirslen)
        self.hybridencode(
            (b'data/123456789/123456789/123456789/123456789/123456789/'
             b'123456789/123456789/123456789/xxxxxxxxx-xxxxxxxxx-'
             b'123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/xxxxxxxxx-xxxx'
             b'4fa04a839a6bda93e1c21c713f2edcbd16e8890d'))

    def testhashnondropped8(self):
        # hashed path with largest non-dropped directory 8
        # (just not hitting the _maxshortdirslen boundary)
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/12345/-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789'
             b'-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/12345/-xxxxxxx'
             b'4d43d1ccaa20efbfe99ec779dc063611536ff2c5'))
        # ...adding one truncated char to dir 1..7 won't drop dir 8
        self.hybridencode(
            (b'data/12345678x/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/12345/xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/1234'
             b'5678/12345/xxxxxxxx0f9efce65189cc60fd90fe4ffd49d7b58bbe0f2e'))
        self.hybridencode(
            (b'data/12345678/12345678x/12345678/12345678/12345678/12345678'
             b'/12345678/12345/xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/1234'
             b'5678/12345/xxxxxxxx945ca395708cafdd54a94501859beabd3e243921'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678x/12345678/12345678/12345678/12'
             b'345678/12345/xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/1234'
             b'5678/12345/xxxxxxxxac62bf6898c4fd0502146074547c11caa751a327'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678x/12345678/12345678/12'
             b'345678/12345/xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/1234'
             b'5678/12345/xxxxxxxx2ae5a2baed7983fae8974d0ca06c6bf08b9aee92'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678x/12345678/'
             b'12345678/12345/xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/1234'
             b'5678/12345/xxxxxxxx214aba07b6687532a43d1e9eaf6e88cfca96b68c'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678x'
             b'/12345678/12345/xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/1234'
             b'5678/12345/xxxxxxxxe7a022ae82f0f55cf4e0498e55ba59ea4ebb55bf'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'12345678x/12345/xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/12345'
             b'678/12345/xxxxxxxxb51ce61164996a80f36ce3cfe64b62d519aedae3'))

    def testhashedpathshortestdropped8(self):
        # hashed path with shortest dropped directory 8
        # (just hitting the _maxshortdirslen boundary)
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/123456/xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-'
             b'123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/xxxxxxxxx-xxxx'
             b'11fa9873cc6c3215eae864528b5530a04efc6cfe'))

    def testhashedpathdropsdir8fortrailingdotspace(self):
        # hashed path that drops dir 8 due to dot or space at end is
        # encoded, and thus causing to hit _maxshortdirslen
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/1234./-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-'
             b'123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/-xxxxxxxxx-xxx'
             b'602df9b45bec564e2e1f0645d5140dddcc76ed58'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/1234 /-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-'
             b'123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/-xxxxxxxxx-xxx'
             b'd99ff212bc84b4d1f70cd6b0071e3ef69d4e12ce'))
        # ... with dir 8 short enough for encoding
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/12./xx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx'
             b'-123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/12~2e/'
             b'xx-xxxxx7baeb5ed7f14a586ee1cacecdbcbff70032d1b3c'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/12 '
             b'/xx-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-123456'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/12~20/'
             b'xx-xxxxxcf79ca9795f77d7f75745da36807e5d772bd5182'))

    def testextensionsreplicatedonhashedpaths(self):
        # Extensions are replicated on hashed paths. Note that
        # we only get to encode files that end in .i or .d inside the
        # store. Encoded filenames are thus bound in length.
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'12345678/12345/-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12.3'
             b'45.i'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/12'
             b'345678/12345/-xxxxxc10ad03b5755ed524f5286aab1815dfe07729438.i'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'12345678/12345/-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12.3'
             b'45.d'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/12'
             b'345678/12345/-xxxxx9eec83381f2b39ef5ac8b4ecdf2c94f7983f57c8.d'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'12345678/12345/-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12.3'
             b'456.i'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/12'
             b'345678/12345/-xxxxxb7796dc7d175cfb0bb8a7728f58f6ebec9042568.i'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'12345678/12345/-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12.3'
             b'4567.i'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/12'
             b'345678/12345/-xxxxxb515857a6bfeef017c4894d8df42458ac65d55b8.i'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'12345678/12345/-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12.3'
             b'45678.i'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/12'
             b'345678/12345/-xxxxxb05a0f247bc0a776211cd6a32ab714fd9cc09f2b.i'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'12345678/12345/-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12.3'
             b'456789.i'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/12'
             b'345678/12345/-xxxxxf192b48bff08d9e0e12035fb52bc58c70de72c94.i'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'12345678/12345/-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12.3'
             b'456789-.i'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/12'
             b'345678/12345/-xxxxx435551e0ed4c7b083b9ba83cee916670e02e80ad.i'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'12345678/12345/-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12.3'
             b'456789-1.i'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/12'
             b'345678/12345/-xxxxxa7f74eb98d8d58b716356dfd26e2f9aaa65d6a9a.i'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'12345678/12345/-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12.3'
             b'456789-12.i'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/12'
             b'345678/12345/-xxxxxed68d9bd43b931f0b100267fee488d65a0c66f62.i'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'12345678/12345/-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12.3'
             b'456789-123.i'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/12'
             b'345678/12345/-xxxxx5cea44de2b642d2ba2b4a30693ffb1049644d698.i'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'12345678/12345/-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12.3'
             b'456789-1234.i'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/12'
             b'345678/12345/-xxxxx68462f62a7f230b39c1b5400d73ec35920990b7e.i'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'12345678/12345/-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12.3'
             b'456789-12345.i'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/12'
             b'345678/12345/-xxxxx4cb852a314c6da240a83eec94761cdd71c6ec22e.i'))
        self.hybridencode(
            (b'data/12345678/12345678/12345678/12345678/12345678/12345678/'
             b'12345678/12345/-xxxxxxxxx-xxxxxxxxx-xxxxxxxxx-123456789-12.3'
             b'456789-12345-ABCDEFGHIJKLMNOPRSTUVWXYZ-'
             b'abcdefghjiklmnopqrstuvwxyz-ABCDEFGHIJKLMNOPRSTUVWXYZ'
             b'-1234567890-xxxxxxxxx-xxxxxxxxx-xxxxxxxx'
             b'-xxxxxxxxx-wwwwwwwww-wwwwwwwww-wwwwwwwww-wwwwwwwww'
             b'-wwwwwwwww-wwwwwwwww-wwwwwwwww-wwwwwwwww-wwwwwwwww.i'),
            (b'dh/12345678/12345678/12345678/12345678/12345678/12345678/12'
             b'345678/12345/-xxxxx93352aa50377751d9e5ebdf52da1e6e69a6887a6.i'))

    def testpathsoutsidedata(self):
        # paths outside data/ can be encoded
        self.hybridencode(b'metadata/dir/00manifest.i',
                          b'metadata/dir/00manifest.i')
        self.hybridencode(
            (b'metadata/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/12345678/00manifest.i'),
            (b'dh/ata/12345678/12345678/12345678/12345678/12345678'
             b'/12345678/12345678/00manife'
             b'0a4da1f89aa2aa9eb0896eb451288419049781b4.i'))

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
