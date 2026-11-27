# PostgreSQL Windows LTSC2019

Experimental images for Windows Server 2019 (10.0.17763), windows/amd64, process isolation. No WSL or Hyper-V on the target.

Commit the contents of this directory (including `.github/workflows/build.yml`) to a GitHub repository. Run Actions -> PostgreSQL Windows LTSC2019 -> Run workflow. The `windows_base` input accepts a pinned Server Core LTSC2019 digest. Default resolves the current LTSC2019 tag once per run. PostgreSQL versions and archive SHA-256 values are pinned; the Visual Studio VC143 runtime is selected from the hosted runner and its version is recorded in the workflow summary.

Images: `ghcr.io/<owner>/postgres-windows:16.16-ltsc2019`, `17.12-ltsc2019`, `18.7-ltsc2019`. Private registry recommended; verify redistribution terms. Candidate tags are retained for diagnosis. GitHub Actions only verifies archive integrity and image metadata, not execution on Windows Server 2019.

## Smoke test (PowerShell on Windows Server 2019)

Replace image reference with the internal registry after copying the image with regctl or equivalent. Run separately for each version, using a fresh volume/container name (and port if concurrent).

```powershell
$image = 'ghcr.io/<owner>/postgres-windows:16.16-ltsc2019'
docker pull $image
docker run --rm --isolation=process --entrypoint C:\pgsql\bin\postgres.exe $image --version
docker volume create pg16-test-data
docker run -d --name pg16-test --isolation=process -p 127.0.0.1:5432:5432 -e POSTGRES_PASSWORD=TemporaryTestPassword -v 'pg16-test-data:C:\Users\ContainerUser\pgdata' $image
docker logs pg16-test
docker exec pg16-test pg_isready.exe -h 127.0.0.1 -U postgres
# Wait until ready, then verify SQL and persistent storage.
docker exec -e PGPASSWORD=TemporaryTestPassword pg16-test psql.exe -h 127.0.0.1 -U postgres -d postgres -v ON_ERROR_STOP=1 -c 'CREATE TABLE smoke (id int); INSERT INTO smoke VALUES (42);'
docker exec pg16-test pg_ctl.exe stop -D C:\Users\ContainerUser\pgdata\data -m fast -w -t 60
docker start pg16-test
# Wait until ready again.
docker exec -e PGPASSWORD=TemporaryTestPassword pg16-test psql.exe -h 127.0.0.1 -U postgres -d postgres -v ON_ERROR_STOP=1 -c 'SELECT * FROM smoke;'
```

The entrypoint supports PGDATA, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB and postgres arguments. Mount the parent of default PGDATA so both data and initialization marker persist. Existing clusters are never automatically deleted or initialized again; an interrupted initial setup requires manual inspection. This is not a full clone of the upstream Linux image: no init scripts or password-file environment support, no automated graceful shutdown guarantee, no automatic ACL adjustment. If the volume denies ContainerUser access, set appropriate ACLs or use a prepared bind mount; do not switch to Administrator merely to hide the failure. Stop with pg_ctl (disable automatic restart first if enabled). Check logs for clean shutdown and test SQL/volume/restart before production. PostgreSQL 18 EDB builds are not certified on Server 2019. No runtime tests were executed in this environment.
