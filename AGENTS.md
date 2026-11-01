# Fusion operator conventions

- All custom Photoshop-analog operators created in this project must use the `PSN_` prefix in their visible tool names, default node names, and `.fuse` filenames.
- First operator: `PSN_SelectiveColor`.
- Preserve existing compositions when renaming: retain an established internal registry ID unless an explicit migration is implemented. New operators should use a matching `PSN_` registry ID.

# Testing rule

- A new operator is not "done" until it has been tested live in the user's Fusion 20: add it to a simple test comp, render basic cases (normal input, edge cases like missing/odd inputs), and confirm the node renders correctly.
- Acceptance criterion: no red node and no errors in the Fusion console. Check the console after every test, not just the rendered image.
- When a fuse fails, read the exact error from the Fusion console first, fix against the Fusion 20 API actually installed on the machine (e.g. `Image:GetPixel(x, y, pixel)` fills a reusable `Pixel()` object), then retest until clean.

# Agent Execution Profile
- **Priority**: Maximum execution speed. 
- **Behavior**: Bypass deep multi-agent planning and multi-step reasoning for scripting tasks.
- **Output Format**: Generate the final Cinema 4D (.pyp) or Fusion (.fuse) file structure in a single, fast pass.
- **Constraints**: 
  - Zero conversational filler or explanations.
  - Zero web-search latency unless a breaking API change is suspected.
  - Code must be self-contained, fully commented, and ready for production.

