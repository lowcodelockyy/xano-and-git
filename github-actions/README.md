# Xano Deploy Workflows                                                                                                                      
                                                                                                                                               
Three GitHub Actions workflows that automate XanoScript deployment via the [@xano/cli](https://www.npmjs.com/package/@xano/cli), with        
branch-based environments and unit-test gating.                                                                                              

## Workflows                                              

### `xano-deploy-main.yml` — production deploys
Triggered on push to `main`. Creates a fresh `ci` Xano branch from `v1`, pushes the repo, runs all unit tests, deletes the `ci` branch, then
pushes to live (`v1`) and re-runs the tests. The ephemeral `ci` branch acts as a pre-flight check before touching production.                

### `xano-deploy-dev.yml` — feature branch deploys                                                                                           
Triggered on push to any `dev-*` branch. Sanitizes the GitHub branch name into a Xano-safe label, creates the matching Xano branch from `v1`
if it doesn't exist (idempotent — reuses if it does), pushes the code, and runs unit tests. State persists across pushes so iterative work   
isn't wiped.

### `xano-cleanup-dev.yml` — auto-cleanup                 
Triggered on GitHub branch deletion. If the deleted branch matched `dev-*`, deletes the corresponding Xano branch. Keeps the Xano workspace
tidy as feature branches are merged.                                                                                                         

## Setup                                                                                                                                     

1. Add `XANO_AUTH` to your repo secrets (Xano API token).                                                                                    
2. Create a GitHub environment named `xano` (or remove the `environment: xano` line from each workflow).
3. Replace the instance URL and workspace ID in the `Configure Xano CLI profile` step:                                                       
   - `-i "https://<your-instance>.xano.io"`                                                                                                  
   - `-w <workspace-id>`                                                                                                                     

## Notes                                                  

- All workflows share `concurrency: group: xano-deploy` so Xano operations serialize across the suite — prevents simultaneous pushes from    
clashing.
- Branch name sanitization lowercases the name and strips anything outside `[a-z0-9-]`, then collapses repeated/edge dashes. Use `dev-123`   
style names; `feature/foo` would become `feature-foo`.                                                                                       
- GitHub Actions doesn't support branch filters on the `delete` event, so the cleanup job filters via `if: github.event.ref_type == 'branch'
&& startsWith(github.event.ref, 'dev-')` instead.                                                                                            
- Idempotency for the dev branch creation step relies on `xano branch get` returning a non-zero exit code when the branch is missing.

Tweak any specifics (instance URL, workspace ID, the dev-* convention) before publishing. 