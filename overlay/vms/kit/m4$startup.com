$! M4$STARTUP.COM - system startup for GNU m4 on OpenVMS
$!
$! Installed by PCSI into SYS$STARTUP.  Defines the system logical name
$! M4$ROOT, pointing at the installed [M4] directory.  To run it at every
$! boot, add this line to SYS$MANAGER:SYSTARTUP_VMS.COM:
$!
$!     $ @SYS$STARTUP:M4$STARTUP.COM
$!
$! P1 = "INSTALL": also print the post-installation tasks (PCSI runs it so).
$! P1 = "REMOVE":  deassign M4$ROOT instead (PCSI runs it so at removal).
$!
$! Users then define the m4 command with
$!     $ @M4$ROOT:[000000]M4$SETUP.COM
$!
$ set noon
$ mode = f$edit(p1, "UPCASE")
$ if mode .eqs. "REMOVE"
$ then
$   if f$trnlnm("M4$ROOT", "LNM$SYSTEM_TABLE") .nes. "" then -
        deassign/system/executive_mode M4$ROOT
$   exit 1
$ endif
$!
$! This procedure sits in <destination>[SYS$STARTUP]; the product is in
$! <destination>[M4].  Rooted logicals need the physical form:
$! DKA0:[SYS0.SYSCOMMON.SYS$STARTUP] -> DKA0:[SYS0.SYSCOMMON.M4.]
$ proc = f$environment("PROCEDURE")
$ dev = f$parse(proc,,,"DEVICE","NO_CONCEAL")
$ dir = f$edit(f$parse(proc,,,"DIRECTORY","NO_CONCEAL"), "UPCASE") - "]["
$ root = dir - "SYS$STARTUP]" + "M4.]"
$ if root .eqs. dir + "M4.]"
$ then
$   write sys$error "M4$STARTUP: expected to be in a [SYS$STARTUP] directory, not ''dir'"
$   exit 44
$ endif
$ root = root - ".000000"
$ define/system/executive_mode/translation_attributes=concealed M4$ROOT 'dev''root'
$ if f$search("M4$ROOT:[BIN]M4.EXE") .eqs. ""
$ then
$   write sys$error "M4$STARTUP: M4.EXE not found under ''dev'''root'"
$   exit 44
$ endif
$ if mode .nes. "INSTALL" then exit 1
$ say = "write sys$output"
$ say ""
$ say "    Post-installation tasks for GNU m4"
$ say ""
$ say "    At system startup: to define M4$ROOT at every boot, add this line to"
$ say "    SYS$MANAGER:SYSTARTUP_VMS.COM:"
$ say "    $ @SYS$STARTUP:M4$STARTUP.COM"
$ say "    For each user: to define the m4 command, add this line to LOGIN.COM:"
$ say "    $ @M4$ROOT:[000000]M4$SETUP.COM"
$ say ""
$ say "    PRODUCT REMOVE M4 removes the product and deassigns M4$ROOT."
$ say ""
$ exit 1
