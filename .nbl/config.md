# NBL Cycle Configuration

```yaml
nbl_version: "1"
cycle_policy:
  max_tasks_per_run: 6
  allow_phases: ["0A", "1A", "1B", "1C", "1D", "1F"]

# Human gates — tasks with these gate values are never auto-selected
# The loop skips them and reports them in DAILY_REPORT.md as "waiting on you"
gates:
  ANTHROPIC_API_KEY: "Add to api/.env"
  HUMAN:create_supabase_project: "Create Supabase project at supabase.com, paste URL + keys into api/.env"
  HUMAN:xcode_provisioning: "Set up Xcode + Apple Developer account + provisioning profile"
  HUMAN:cloud_storage_credentials: "Create R2/S3 bucket, paste credentials into api/.env"
  HUMAN:apple_developer: "Requires Apple Developer account and TestFlight setup"
```
