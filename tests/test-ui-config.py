from __future__ import absolute_import, print_function
from mercurial import (
    dispatch,
    error,
    ui as uimod,
)

testui = uimod.ui.load()

# disable the configuration registration warning
#
# the purpose of this test is to check the old behavior, not to validate the
# behavior from registered item. so we silent warning related to unregisted
# config.
testui.setconfig(b'devel', b'warn-config-unknown', False, b'test')
testui.setconfig(b'devel', b'all-warnings', False, b'test')

parsed = dispatch._parseconfig(testui, [
    b'values.string=string value',
    b'values.bool1=true',
    b'values.bool2=false',
    b'values.boolinvalid=foo',
    b'values.int1=42',
    b'values.int2=-42',
    b'values.intinvalid=foo',
    b'lists.list1=foo',
    b'lists.list2=foo bar baz',
    b'lists.list3=alice, bob',
    b'lists.list4=foo bar baz alice, bob',
    b'lists.list5=abc d"ef"g "hij def"',
    b'lists.list6="hello world", "how are you?"',
    b'lists.list7=Do"Not"Separate',
    b'lists.list8="Do"Separate',
    b'lists.list9="Do\\"NotSeparate"',
    b'lists.list10=string "with extraneous" quotation mark"',
    b'lists.list11=x, y',
    b'lists.list12="x", "y"',
    b'lists.list13=""" key = "x", "y" """',
    b'lists.list14=,,,,     ',
    b'lists.list15=" just with starting quotation',
    b'lists.list16="longer quotation" with "no ending quotation',
    b'lists.list17=this is \\" "not a quotation mark"',
    b'lists.list18=\n \n\nding\ndong',
    b'date.epoch=0 0',
    b'date.birth=2005-04-19T00:00:00',
    b'date.invalid=0'
    ])

print(repr(testui.configitems(b'values')))
print(repr(testui.configitems(b'lists')))
print("---")
print(repr(testui.config(b'values', b'string')))
print(repr(testui.config(b'values', b'bool1')))
print(repr(testui.config(b'values', b'bool2')))
print(repr(testui.config(b'values', b'unknown')))
print("---")
try:
    print(repr(testui.configbool(b'values', b'string')))
except error.ConfigError as inst:
    print(inst)
print(repr(testui.configbool(b'values', b'bool1')))
print(repr(testui.configbool(b'values', b'bool2')))
print(repr(testui.configbool(b'values', b'bool2', True)))
print(repr(testui.configbool(b'values', b'unknown')))
print(repr(testui.configbool(b'values', b'unknown', True)))
print("---")
print(repr(testui.configint(b'values', b'int1')))
print(repr(testui.configint(b'values', b'int2')))
print("---")
print(repr(testui.configlist(b'lists', b'list1')))
print(repr(testui.configlist(b'lists', b'list2')))
print(repr(testui.configlist(b'lists', b'list3')))
print(repr(testui.configlist(b'lists', b'list4')))
print(repr(testui.configlist(b'lists', b'list4', [b'foo'])))
print(repr(testui.configlist(b'lists', b'list5')))
print(repr(testui.configlist(b'lists', b'list6')))
print(repr(testui.configlist(b'lists', b'list7')))
print(repr(testui.configlist(b'lists', b'list8')))
print(repr(testui.configlist(b'lists', b'list9')))
print(repr(testui.configlist(b'lists', b'list10')))
print(repr(testui.configlist(b'lists', b'list11')))
print(repr(testui.configlist(b'lists', b'list12')))
print(repr(testui.configlist(b'lists', b'list13')))
print(repr(testui.configlist(b'lists', b'list14')))
print(repr(testui.configlist(b'lists', b'list15')))
print(repr(testui.configlist(b'lists', b'list16')))
print(repr(testui.configlist(b'lists', b'list17')))
print(repr(testui.configlist(b'lists', b'list18')))
print(repr(testui.configlist(b'lists', b'unknown')))
print(repr(testui.configlist(b'lists', b'unknown', b'')))
print(repr(testui.configlist(b'lists', b'unknown', b'foo')))
print(repr(testui.configlist(b'lists', b'unknown', [b'foo'])))
print(repr(testui.configlist(b'lists', b'unknown', b'foo bar')))
print(repr(testui.configlist(b'lists', b'unknown', b'foo, bar')))
print(repr(testui.configlist(b'lists', b'unknown', [b'foo bar'])))
print(repr(testui.configlist(b'lists', b'unknown', [b'foo', b'bar'])))
print("---")
print(repr(testui.configdate(b'date', b'epoch')))
print(repr(testui.configdate(b'date', b'birth')))

print(repr(testui.config(b'values', b'String')))

def function():
    pass

# values that aren't strings should work
testui.setconfig(b'hook', b'commit', function)
print(function == testui.config(b'hook', b'commit'))

# invalid values
try:
    testui.configbool(b'values', b'boolinvalid')
except error.ConfigError:
    print('boolinvalid')
try:
    testui.configint(b'values', b'intinvalid')
except error.ConfigError:
    print('intinvalid')
try:
    testui.configdate(b'date', b'invalid')
except error.ConfigError:
    print('dateinvalid')
