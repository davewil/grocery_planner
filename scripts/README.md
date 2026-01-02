# Scripts

## Sync AI backlog to GitHub Issues

Source of truth: `docs/ai_backlog.md`

### Create everything (labels + epics + story issues + links)

```powershell
./scripts/sync-ai-backlog-issues.ps1 -All
```

### Dry run

```powershell
./scripts/sync-ai-backlog-issues.ps1 -All -DryRun
```

### Common incremental flows

- If you only added new stories:

```powershell
./scripts/sync-ai-backlog-issues.ps1 -CreateStories -LinkStoriesToEpics
```

- If you added new epics too:

```powershell
./scripts/sync-ai-backlog-issues.ps1 -CreateEpics -CreateStories -LinkStoriesToEpics
```

Notes:
- Script is idempotent (matches by issue title prefix).
- Epic linking writes a bounded block in each epic issue body between:
  - `<!-- story-issues-start -->`
  - `<!-- story-issues-end -->`
