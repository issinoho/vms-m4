$! M4$SETUP.COM - define the m4 command for a user
$!
$! Add to LOGIN.COM (or SYS$MANAGER:SYLOGIN.COM for everyone):
$!     $ @M4$ROOT:[000000]M4$SETUP.COM
$!
$! Upper-case options (-D, -I, -U, ...) need SET PROCESS/PARSE_STYLE=EXTENDED,
$! or double quotes, because traditional DCL parsing changes their case;
$! batch jobs use the traditional style.
$!
$ if f$trnlnm("M4$ROOT") .eqs. ""
$ then
$   write sys$error "M4$SETUP: M4$ROOT is not defined; run M4$STARTUP.COM first"
$   exit 44
$ endif
$ m4 :== $M4$ROOT:[BIN]M4.EXE
$ exit 1
