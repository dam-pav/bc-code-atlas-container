# bc-code-atlas container deployment

This standalone project containerizes [`StefanMaron/bc-code-atlas`](https://github.com/StefanMaron/bc-code-atlas). The upstream source is fetched while building the image; no source checkout is required beside these deployment files.

The image runs all five cooperating processes and exposes only the unified MCP endpoint on port 8800. Corpus, indexes, model cache, and on-demand version data remain persistent outside image layers.

The container creates a local `./data` directory during first-start bootstrap. It contains downloaded upstream AL source and Microsoft documentation, generated indexes, and other runtime state. It is intentionally excluded from Git and is not part of this repository's source.

## Requirements

This project builds and runs a **Linux container**. The Docker host must support Linux containers; Windows containers are not supported. Run it with a regular Docker Engine installation or another Linux container platform such as Kubernetes. Portainer deployments must target an environment capable of running Linux containers.

The deployment definitions in this repository target Docker Compose and Portainer. Kubernetes requires equivalent workload, service, health-probe, and persistent-volume manifests, which are not currently included. CLI deployment requires Docker Engine with the Docker Compose plugin. GPU deployment also requires a supported NVIDIA GPU, driver, and container runtime integration.

## Deployment

Choose either deployment method below. Both use the same configuration and automatically bootstrap missing persistent data before starting the MCP servers. No post-deployment configuration change is required.

### Option A: Docker Compose CLI

Use this workflow from a terminal on the Docker host.

1. Optionally copy and edit the environment file:

   ```bash
   cp .env.example .env
   ```
2. Build the image and start the service:

   ```bash
   docker compose up -d --build
   ```

   On first startup, the container downloads the upstream corpora and builds both indexes before starting the MCP servers. This is compute-, network-, and disk-intensive. Later starts reuse the persistent data automatically.

CPU is the default. For CUDA, install the NVIDIA Container Toolkit and use both Compose files for every command:

```bash
docker compose -f compose.yaml -f compose.gpu.yaml up -d --build
```

To include a specific upstream tag, branch, or commit in the image, set `BC_CODE_ATLAS_REF` before building:

```bash
BC_CODE_ATLAS_REF=<git-ref> docker compose build
```

### Option B: Portainer Git repository

Use this workflow entirely through the Portainer UI.

1. In Portainer, open **Stacks**, select **Add stack**, and choose **Git repository**.
2. Enter this project's Git repository URL and select the branch or tag to deploy. This is the containerization repository, not the upstream `bc-code-atlas` repository. Leave **Authentication** disabled because this repository is public.
3. Set **Compose path** to `compose.yaml`.
4. On a Docker Standalone environment, set **Local filesystem path** to a stable, writable host directory. The relative `./data` bind mount is created beneath this directory and must remain available across stack updates.
5. Under **Environment variables**, add any values from `.env.example` that should differ from their defaults, including `BC_CODE_ATLAS_REF` when deploying a particular upstream version. No bootstrap variable is needed.
6. Select **Deploy the stack**, then follow the container logs. The first start downloads the source corpora and builds the indexes before starting the MCP servers, which can take a long time.
7. When the logs report `Bootstrap complete`, the container continues into normal service startup. Subsequent deployments reuse the initialized data.

Portainer Business Edition can apply `compose.gpu.yaml` through **Additional paths** for an NVIDIA deployment; keep `compose.yaml` as the main Compose path. The Docker host must already have the NVIDIA Container Toolkit. Without the additional file, the Portainer deployment uses CPU.

Portainer clones the Git repository when deploying a Git-backed stack and does not initialize its submodules. This deployment does not rely on Portainer's submodule support: the Docker build fetches the upstream application and the bootstrap process fetches its corpus submodules. See the [Portainer Git stack documentation](https://docs.portainer.io/sts/user/docker/stacks/add) for the current field descriptions and GitOps update options.

After either workflow completes, the MCP endpoint is `http://<docker-host>:8800/mcp` unless `BCATLAS_PORT` changes the published port. `.env.example` lists all supported build, networking, embedding, indexing, graph, and retention parameters with their defaults.

### Connect an MCP client

Replace `<docker-host>` with the hostname or IP address reachable from the client. Use `localhost` only when the client runs on the Docker host.

#### GitHub Copilot

For GitHub Copilot in Visual Studio Code, use the built-in MCP setup:

1. Open the command palette and run **MCP: Add Server**.
2. Choose **HTTP (HTTP or Server-Sent Events)**.
3. Enter `http://<docker-host>:8800/mcp`.
4. Enter `bc-code-atlas` as the server name.
5. Choose **Workspace** to create `.vscode/mcp.json` for the current repository, or **Global** to make the server available in all workspaces.
6. Run **MCP: List Servers** from the command palette, select `bc-code-atlas`, and choose **Start Server** if it is listed as stopped. You can also open `.vscode/mcp.json` and use the **Start** action shown above the server definition. Then open Copilot Chat in Agent mode and confirm that the `bcatlas_*` tools appear in the tool picker.

For a repository-managed configuration, create `.vscode/mcp.json` directly:

```json
{
  "servers": {
    "bc-code-atlas": {
      "type": "http",
      "url": "http://<docker-host>:8800/mcp"
    }
  }
}
```

GitHub documents workspace and user-level configuration in [Extending GitHub Copilot Chat with MCP servers](https://docs.github.com/en/copilot/how-tos/provide-context/use-mcp-in-your-ide/extend-copilot-chat-with-mcp). GitHub Copilot CLI uses `.mcp.json` with an `mcpServers` top-level object instead of VS Code's `.vscode/mcp.json` format; see [Adding MCP servers for GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers).

#### Codex

Add the streamable HTTP server with the Codex CLI:

```bash
codex mcp add bc-code-atlas --url http://<docker-host>:8800/mcp
codex mcp list
```

Alternatively, add the following to the user-level `~/.codex/config.toml` or a trusted project's `.codex/config.toml`:

```toml
[mcp_servers.bc-code-atlas]
url = "http://<docker-host>:8800/mcp"
```

Restart Codex after editing the file, then use `/mcp` to verify that the server is active. The Codex CLI, IDE extension, and ChatGPT desktop app on the same host share this configuration. See the official OpenAI [Codex MCP documentation](https://developers.openai.com/codex/mcp/).

## Reference

All environment variables are optional because the Compose configuration provides defaults. Variables used during image build or bootstrap must be set before running the corresponding command; changing them afterward does not retroactively rebuild the image or existing indexes.

| Name                                | Description                                                                                                                                                                                                                                                          |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `BC_CODE_ATLAS_REPOSITORY`        | Git repository fetched into the image. Defaults to the official`StefanMaron/bc-code-atlas` repository.                                                                                                                                                             |
| `BC_CODE_ATLAS_REF`               | Upstream Git tag, branch, or commit included in the Docker image. Defaults to`master`. After changing it, run `docker compose build` again.                                                                                                                      |
| `BCATLAS_PORT`                    | Host port mapped to the aggregator's container port 8800. Defaults to`8800`.                                                                                                                                                                                       |
| `BCATLAS_HEALTH_START_PERIOD`     | Grace period during which failed health checks do not count toward the retry limit while initial bootstrap runs. Accepts Docker Compose durations such as`30m`, `2h`, or `4h`; defaults to `4h`. A successful check makes the container healthy immediately. |
| `AGGREGATOR_PUBLIC_HOSTNAME`      | Public hostname accepted by the MCP aggregator when deployed behind a reverse proxy or tunnel. Leave empty for local access.                                                                                                                                         |
| `BCATLAS_EMBEDDING_MODEL`         | Hugging Face sentence-transformers model written to the CocoIndex configuration during the first bootstrap.                                                                                                                                                          |
| `BCATLAS_EMBEDDING_DEVICE`        | Embedding device used during bootstrap and indexing. Defaults to`cpu`; the GPU Compose override sets it to `cuda`.                                                                                                                                               |
| `BCATLAS_BUILD_MAX_CONCURRENT`    | Maximum number of concurrent GPU- or CPU-bound on-demand version builds. Defaults to`1`.                                                                                                                                                                           |
| `BCATLAS_BUILD_MIN_OVERLAP_RATIO` | Minimum source-file overlap required to reuse a warm sibling index for an incremental build. Defaults to`0.5`.                                                                                                                                                     |
| `BCATLAS_CCC_STALL_TIMEOUT_S`     | Seconds without index progress before an on-demand CocoIndex process is considered stalled. Defaults to`300`.                                                                                                                                                      |
| `BCATLAS_CCC_INDEX_MAX_TOTAL_S`   | Maximum total duration, in seconds, of an on-demand indexing process. Defaults to`14400` (four hours).                                                                                                                                                             |
| `BCATLAS_WARM_DISK_BUDGET_BYTES`  | Disk budget in bytes for warm on-demand version artifacts. Defaults to`53687091200` (50 GiB).                                                                                                                                                                      |
| `BCATLAS_WATCH_INTERVAL_SECONDS`  | Interval in seconds for continuously reindexing changed source files. Empty disables watch mode.                                                                                                                                                                     |
| `GRAPHIFY_MAX_GRAPH_BYTES`        | Maximum graph JSON file size accepted by graphify-al. Supports size strings such as`1GB`, which is the default.                                                                                                                                                    |
| `GRAPHIFY_INSTRUCTIONS`           | Custom MCP instructions exposed by the graph server. Empty uses the upstream Business Central instructions; use a Compose override for multiline text.                                                                                                               |

### Volumes

| Volume                | Container path               | Description                                                                                                                                                                                                                                                                                                                                                               |
| --------------------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `./data`            | `/app/data`                | Host bind mount containing downloaded Business Central and documentation repositories, generated semantic and graph indexes, the shared upstream Git mirror, and warm on-demand version artifacts. This is the deployment's primary persistent data. Deleting it discards all generated and warm data; the container automatically bootstraps it again on its next start. |
| `huggingface-cache` | `/root/.cache/huggingface` | Docker-managed volume containing downloaded Hugging Face model files. Keeping it avoids downloading the embedding model again when containers or images are replaced. Removing it does not delete indexes, but the model must be downloaded again.                                                                                                                        |
| `cocoindex-runtime` | `/root/.cocoindex_code`    | Docker-managed volume containing the CocoIndex global configuration and user-level runtime state. Bootstrap creates`global_settings.yml` here from the embedding variables. Removing it causes bootstrap to recreate the configuration; existing indexes may need to be rebuilt if the recreated embedding configuration differs.                                       |

Named volumes survive `docker compose down`. Running `docker compose down -v` also removes `huggingface-cache` and `cocoindex-runtime`; it does not remove the host-mounted `./data` directory.
