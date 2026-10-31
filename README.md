# 9Remote GitHub Actions Workflow Runner

Run the [9Remote](https://9remote.cc) daemon as a headless interactive terminal service on GitHub Actions (`ubuntu-latest`). This setup launches `9remote start`, enables automatic device connection approvals, and prints connection details (One-Time Key and Permanent Key) directly to the GitHub Actions execution log.

## Prerequisites

- GitHub Repository (`Delta-Kronecker/9remote` or your fork).
- Access to trigger `workflow_dispatch` manually via GitHub UI or GitHub CLI (`gh`).

## Quick Setup Instructions

1. **Trigger the Workflow**:
   - Go to your repository on GitHub: `https://github.com/Delta-Kronecker/9remote/actions`.
   - Select the **9Remote Tunnel Runner** workflow.
   - Click **Run workflow**.
   - Optionally adjust the parameters:
     - `duration`: Keep-alive period in hours (Default: `6`, Maximum: `24`).
     - `auto_approve`: Automatically approve new incoming connections (Default: `true`).

2. **Trigger via GitHub CLI (`gh`)**:
   ```bash
   gh workflow run 9remote.yml -f duration=6 -f auto_approve=true
   ```

3. **Get Connection Credentials**:
   - Click on the active workflow run log.
   - Open the **Start 9Remote Service** step.
   - Look for the `9REMOTE GITHUB RUNNER READY` box containing your keys:
     - **Web Login URL**: `https://9remote.cc/login`
     - **One-Time Key**: 6-digit key (Expires in 30 minutes)
     - **Permanent Key**: Persistent device key

4. **Connect to the Runner**:
   - Open `https://9remote.cc/login` or open the 9Remote App on your device.
   - Enter either the One-Time Key or Permanent Key.
   - You now have an active shell session on the GitHub Actions runner environment.

## Workflow Configuration Options

| Input Parameter | Type | Default | Description |
|---|---|---|---|
| `duration` | String | `6` | Number of hours to keep the session active (1 to 24). |
| `auto_approve` | Boolean | `true` | Automatically approve pair/connect requests without manual confirmation. |

## Runtime Limits & Caveats

- **GitHub Actions Execution Cap**: Workflow jobs are subject to a maximum timeout of 6 hours by default (up to 24 hours depending on plan limits).
- **Free Plan Usage**: GitHub free accounts have 2,000 Action minutes per month.
- **Ephemeral Storage**: Files saved on the runner are destroyed when the workflow finishes.

## Troubleshooting

| Symptom | Cause | Solution |
|---|---|---|
| `Error: 9Remote server failed to start` | Server did not bind to port 2208 in time. | Re-run workflow; check log output under `--- 9Remote Server Logs ---`. |
| `Key rejected or expired` | One-Time Key expired (30m limit). | Use the Permanent Key displayed in the logs or trigger a new workflow run. |
| `Workflow cancelled unexpectedly` | Exceeded job timeout or monthly quota. | Ensure `duration` parameter matches your plan's job limit. |
