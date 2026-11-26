# Contributing

Thanks for wanting to help out. This is a community-made SDK, so contributions are genuinely welcome.

## What's most useful right now

- **Real playtest reports.** The SDK follows FirstLook's published API spec at `https://api.firstlook.gg/client/docs` (the raw spec is at `/client/openapi.json`). A few details the spec does not spell out are listed under "Not yet confirmed" in the README. If you run a real playtest and see something off in your dashboard, an issue or PR is hugely helpful.
- **Bug reports.** Open an issue with your Godot version, GodotSteam version, and what went wrong. Include the output log if you can.
- **Survey UI improvements.** `survey_screen.gd` builds everything in code. Theme support or controller navigation would be great additions.

## How to contribute

1. Fork the repo.
2. Create a branch: `git checkout -b fix/whatever-you-are-fixing`
3. Make your changes.
4. Open a pull request with a clear description of what changed and why.

## Ground rules

- Keep PRs focused. One thing per PR is easier to review.
- GDScript only. No C#.
- Test against Godot 4.7+ before submitting.
- If you are adding a new feature, add a usage example in the PR description.

## Not sure if something is worth a PR?

Open an issue first and we can talk it through.
