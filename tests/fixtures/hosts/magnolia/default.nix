# The macOS fixture: a non-default account under /Users, as on a work Mac, and
# both T3 Code traits, so the nightly desktop app and CLI are both built, and
# the TLS inspection CA trait with a fake CA, and the network recovery trait.
{
  my.user.name = "tester";
  my.user.home = "/Users/tester";
  my.t3.cli.enable = true;
  my.t3.desktop.enable = true;
  my.tlsInspectionCa.enable = true;
  my.networkRecovery.enable = true;
}
