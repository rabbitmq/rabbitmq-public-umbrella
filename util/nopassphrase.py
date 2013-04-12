# A Python/pexpect script that supplies an empty passphrase to RPM
# signing operations
import sys, pexpect
child = pexpect.spawn(sys.argv[1], sys.argv[2:], logfile=sys.stdout)
child.expect('[Pp]ass *[Pp]hrase:')
child.sendline('')
child.expect(pexpect.EOF)
child.close()
sys.exit(child.exitstatus)
