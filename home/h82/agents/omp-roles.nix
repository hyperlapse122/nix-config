{
  defaultThinkingLevel = "high";
  github.enabled = true;
  modelRoles = {
    default = "google-antigravity/gemini-4-argon";
    smol = "google-antigravity/gemini-3.5-flash-lite:low";
    slow = "google-antigravity/gemini-4-argon:high";
    plan = "google-antigravity/gemini-4-argon:high";
    task = "google-antigravity/gemini-3.8-flash:low";
    commit = "google-antigravity/gemini-3.5-flash-lite:minimal";
    web = "web/synthetic";
  };
  task = {
    structured = true;
    enableEffort = true;
    maxEffort = "high";
    agentModelOverrides = {
      sonic = "google-antigravity/gemini-3.5-flash-lite:minimal";
      scout = "google-antigravity/gemini-3.5-flash-lite:low";
      seance = "google-antigravity/gemini-3.5-flash-lite:low";
      task = "google-antigravity/gemini-3.8-flash:low";
      reviewer = "google-antigravity/gemini-3.8-flash:medium";
      "security-reviewer" = "google-antigravity/gemini-3.8-flash:medium";
      architect = "google-antigravity/gemini-4-argon:high";
    };
  };
}
