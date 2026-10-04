$! TEST_SMOKE.COM - smoke test for the built m4 ([.BIN_<arch>]M4.EXE)
$!
$! Usage:  @[.VMS]TEST_SMOKE
$!
$ set noon
$ saved_default = f$environment("DEFAULT")
$ proc = f$environment("PROCEDURE")
$ vmsdir = f$parse(proc,,,"DEVICE") + f$parse(proc,,,"DIRECTORY")
$ set default 'vmsdir'
$ set default [-]
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ m4 = "$" + f$parse("[.BIN_''arch']M4.EXE")
$ pass = 0
$ fail = 0
$ if f$search("SMOKE.DIR") .eqs. "" then create/directory [.SMOKE]
$ set default [.SMOKE]
$ set process/parse_style=extended
$!
$! 1. version
$ define/user sys$output out.txt
$ m4 --version
$ search/nooutput out.txt "GNU M4) 1.4"
$ sev = $severity
$ name = "version"
$ gosub check_success
$!
$! 2. define and expand a macro (also: output written as whole lines)
$ create in2.m4
define(`greet', `Hello, $1!')dnl
greet(`OpenVMS')
second line
$ define/user sys$output out.txt
$ m4 in2.m4
$ search/nooutput/exact out.txt "Hello, OpenVMS!"
$ sev = $severity
$ name = "define and expand"
$ gosub check_success
$ search/nooutput/exact out.txt "second line"
$ sev = $severity
$ name = "output written as lines"
$ gosub check_success
$!
$! 3. eval
$ create in3.m4
eval(`2**10 + 7 * 6')
$ define/user sys$output out.txt
$ m4 in3.m4
$ search/nooutput/exact out.txt "1066"
$ sev = $severity
$ name = "eval"
$ gosub check_success
$!
$! 4. include and diversions
$ create inc4.m4
define(`FROMINC', `included text')dnl
$ create in4.m4
include(`inc4.m4')dnl
divert(1)second
divert(0)first FROMINC
undivert(1)dnl
$ define/user sys$output out.txt
$ m4 in4.m4
$ search/nooutput/match=and out.txt "first","included text"
$ sev = $severity
$ name = "include and divert"
$ gosub check_success
$!
$! 5. syscmd runs a DCL command; sysval is 0 on success, non-zero on failure
$ create in5.m4
syscmd(`write sys$output "from-dcl"')sysval
syscmd(`directory nonexistent.file')sysval
$ define/user sys$output out.txt
$ define/user sys$error nla0:
$ m4 in5.m4
$ search/nooutput/exact out.txt "from-dcl"
$ sev = $severity
$ name = "syscmd runs DCL"
$ gosub check_success
$ search/nooutput/exact out.txt "0"
$ sev = $severity
$ name = "sysval 0 after success"
$ gosub check_success
$!
$! 6. esyscmd captures the output of a DCL command
$ create in6.m4
[esyscmd(`write sys$output "captured"')]
$ define/user sys$output out.txt
$ m4 in6.m4
$ search/nooutput out.txt "[captured"
$ sev = $severity
$ name = "esyscmd captures output"
$ gosub check_success
$!
$! 7. a missing input file gives an error status
$ define/user sys$error nla0:
$ m4 nonexistent.m4
$ sev = $severity
$ name = "missing file gives an error status"
$ gosub check_failure
$!
$ write sys$output "SMOKE: ''pass' passed, ''fail' failed"
$ delete/nolog *.*;*
$ set default [-]
$ set file/protection=o:rwed SMOKE.DIR
$ delete/nolog SMOKE.DIR;
$ set default 'saved_default'
$ if fail .eq. 0 then exit 1
$ exit 44
$!
$! The callers save $SEVERITY in sev straight after the command: any
$! assignment (name = ...) resets it.
$check_success:
$ if sev .eq. 1
$ then
$   pass = pass + 1
$   write sys$output "PASS: ", name
$ else
$   fail = fail + 1
$   write sys$output "FAIL: ", name, " (severity ", sev, ")"
$   if f$search("out.txt") .nes. ""
$   then
$     write sys$output "   output was:"
$     type out.txt;0
$   endif
$ endif
$ return
$!
$check_failure:
$ if sev .eq. 2 .or. sev .eq. 4
$ then
$   pass = pass + 1
$   write sys$output "PASS: ", name
$ else
$   fail = fail + 1
$   write sys$output "FAIL: ", name, " (severity ", sev, ", expected an error)"
$ endif
$ return
