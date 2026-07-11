# Contributing

Thanks for wanting to help out. This is a community-made SDK, so contributions are genuinely welcome.

## What's most useful right now

- **API endpoint corrections.** The endpoint paths are modeled on the Unity SDK docs. If you have a FirstLook account and find any discrepancies against the live Swagger UI at `https://api.firstlook.gg/client/swagger-ui/`, a PR with corrections would be huge.
- **Bug reports.** Open an issue with your Godot version, GodotSteam version, and what went wrong. Include the output log if you can.
- **Survey UI improvements.** The `survey_screen.gd` builds everything in code. If you build something nicer (a proper `.tscn` with theming support, for example), feel free to PR it.

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
