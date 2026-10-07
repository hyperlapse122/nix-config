# The macOS fixture: a non-default account under /Users, as on a work Mac, and
# both T3 Code traits, so the nightly desktop app and CLI are both built.
{
  my.user.name = "tester";
  my.user.home = "/Users/tester";
  my.t3.cli.enable = true;
  my.t3.desktop.enable = true;
}
