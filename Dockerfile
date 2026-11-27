# escape=`
ARG WINDOWS_BASE=mcr.microsoft.com/windows/servercore:ltsc2019
FROM ${WINDOWS_BASE}
ARG PG_VERSION
ENV PG_VERSION=${PG_VERSION} `
    PGDATA="C:\Users\ContainerUser\pgdata\data" `
    POSTGRES_USER=postgres `
    PATH="C:\pgsql\bin;C:\Windows\System32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0"
COPY pgsql/ C:/pgsql/
COPY entrypoint.ps1 C:/entrypoint.ps1
USER ContainerUser
EXPOSE 5432
ENTRYPOINT ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe", "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", "C:\\entrypoint.ps1"]
